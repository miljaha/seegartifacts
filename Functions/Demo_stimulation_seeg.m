%% Initialization
clear; close all; clc;
addpath(genpath('Main Functions'));
addpath(genpath('Auxiliary Functions'));

%% Parameters
subj_num       = 22;                             % subject number
edf_filename   = "EEG_278-export.edf";           % edf filename
datetime_range = {"2-3-2020 10:52:40","2-3-2020 10:53:15"};
stim_freq      = 1;                              % Stimulation frequency
stim_current   = 5;                              % Stimulation current
user_measure   = ["R","FR"];                     % detection measures
dataset_dir    = "C:\Datasets\Data";             % directory of the dataset

%% Checking the input datetime range
data_dir = dataset_dir + "\Pat" + string(subj_num) + "\Stimulation_Files";
datetime_range = check_datetime(datetime_range);
[data_length, sampling_rate, start_datetime, end_datetime, datetime_range, edf_filename] = check_files(data_dir, edf_filename, datetime_range);
[edf_filename, start_datetime, end_datetime, sampling_rate, sample_window, num_edf_files] = exclude_files(edf_filename, datetime_range, start_datetime, end_datetime, data_length, sampling_rate);

%% Checking the selected detection measure
short_list_of_measures = ["r","fr","s","sr","sfr","gs"];
complete_list_of_measures = ["Ripples","Fast-Ripples","Spikes","Spike-Ripples",...
    "Spike-Fast-Ripples","Gamma-Spikes"];
user_measure = check_measure(user_measure, short_list_of_measures, complete_list_of_measures);

%% Loading SEEG data
[fs, N, label, events] = check_data(data_dir, edf_filename);
artefact_samples = extract_artefact_locations(events, N, fs); % search for the artefact samples in the file
if ~isempty(artefact_samples)
    artefact_samples = artefact_samples(artefact_samples(:,2) <= sample_window(2),:);
end
bad_samples = artefact_samples;
data = edfread_with_range(fullfile(data_dir, edf_filename), sample_window, sample_window(2));

%% Preprocessing raw data
[exclude_channel_mask, bipolar_labels] = exclude_channels(subj_num, label);
data = uni2bi_montage(data', label); % convert the data to the bipolar montage
x = data.x_bip; clear data;

%% Band-pass filter the processed data
BandpassOrder  = 1024;                          % General bandpass filter order
Freq_band_edge = [0 70 80 500 510 fs/2].*2/fs;  % Vector of frequency band edges
Amp_freq_edge  = [0 0 1 1 0 0];                 % Amplitude for each frequency edge
Error_weight   = [50 1 50];                     % Error weight vector in dB (the last error weight is changed from 1 to 10)
% Design the Parks-McClellan optimal equiripple FIR filter
BandpassFilter = firpm(BandpassOrder, Freq_band_edge, Amp_freq_edge, Error_weight);
% Apply the filter to a padded signal becasue the output will have a BandpassOrder/2 shift in response
x = filter(BandpassFilter, 1, [x'; zeros(BandpassOrder/2,size(x,1))]);
% Remove the delay in the filter response
x(1:BandpassOrder/2,:) = []; x = x';

%% Loading and preparing detection results
results = load(fullfile(data_dir, "Detection Results", erase(edf_filename, ".edf") + ...
    "_stimulation_detections_at_" + stim_freq + "Hz_" + stim_current + "mA_" ...
    + strjoin(lower(user_measure),"_") + ".mat"));
y = cell(1,length(user_measure));

trigger_pos = results.Summary.stimulation_pulses_location;
trigger_pos = vertcat(trigger_pos{:});
trigger_pos(trigger_pos < sample_window(1) | trigger_pos > sample_window(2)) = [];
trigger_pos = trigger_pos - sample_window(1);

for i = 1:length(user_measure)
    switch user_measure(i)
        case "r"
            F = results.Summary.R_artefacts_removed;
        case "fr"
            F = results.Summary.FR_artefacts_removed;
        case "s"
            F = results.Summary.IED_artefacts_removed;
        case "sr"
            F = results.Summary.SR_artefacts_removed;
        case "sfr"
            F = results.Summary.SFR_artefacts_removed;
        case "gs"
            F = results.Summary.GS_artefacts_removed;
    end

    F = vertcat(F{:});
    F(:,3:4) = round(F(:,3:4));
    idx1 = F(:,3) >= sample_window(1);
    idx2 = (F(:,3) + F(:,4)) <= sample_window(2);
    idx3 = (F(:,3) < sample_window(1)) & ((F(:,3) + F(:,4)) >= sample_window(1));
    idx4 = ((F(:,3) + F(:,4)) > sample_window(2)) & (F(:,3) <= sample_window(2));
    F(idx3,3) = sample_window(1);
    F(idx4,4) = sample_window(2) - F(idx4,3);
    y{i} = nan(size(x));
    if any((idx1 & idx2) | idx3 | idx4)
        FF = F((idx1 & idx2) | idx3 | idx4,:);
        FF(:,3) = FF(:,3) - sample_window(1) + 1;
        for j = 1:size(FF,1)
            y{i}(FF(j,1),FF(j,3):(FF(j,3) + FF(j,4))) = x(FF(j,1),FF(j,3):(FF(j,3) + FF(j,4)));
        end
    end
    y{i} = y{i}(~exclude_channel_mask,:);              % exclude bad channels from data
end
x = x(~exclude_channel_mask,:);                            % exclude bad channels from data
bipolar_labels = bipolar_labels(~exclude_channel_mask,:);  % exclude bad channels from labels
bad_mask = false(1,size(x,2));
for i = 1:size(bad_samples,1)
    bad_mask(bad_samples(i,1):bad_samples(i,2)) = true;
end

%% Plotting
plot_spacing = 20;
t = 0:1/fs:seconds(duration(datetime_range{2}-datetime_range{1}));
t_dt = datetime_range{1} + seconds(t);
figure('color','w','WindowState','maximized'); box on;
tiledlayout(20,1,"TileSpacing","compact","Padding","compact");
A1 = nexttile(1,[20-1 1]);
ax1 = zeros(1,length(user_measure)+2);
ax1(1) = plot_multichannel(x, plot_spacing, t, 'k', 0.5); hold on;
if isempty(trigger_pos)
    trigger_pos = nan;
end
ax = xline(trigger_pos/fs,'color','m','LineWidth',1.5);
ax1(2) = ax(1); hold on;
c = [0.000, 0.447, 0.741
    0.850, 0.325, 0.098
    0.494, 0.184, 0.556
    0.466, 0.674, 0.188
    0.910, 0.525, 0.100
    0.301, 0.745, 0.933];

for i = 1:length(user_measure)
    ax1(i+2) = plot_multichannel(y{i}, plot_spacing, t,c(i,:), 0.5); hold on;
end
legend(ax1,["SEEG [80-500] Hz","Stimulations (" + stim_current + "mA at" + stim_freq + "Hz)", ...
    upper(user_measure) + " Detections"],'fontsize',10);
xlim([t(1) t(end)]); xticklabels(string(datetime_range{1} + seconds(xticks)));
set(gca,'Yticklabels',flipud(upper(bipolar_labels)),'fontsize',6);
A2 = nexttile(20);
imagesc(t,ones(size(t)),bad_mask); xlim([t(1) t(end)]);
set(gca,'Xticklabels','','Yticklabels',''); xlabel("Artefact Annotation");
linkaxes([A1 A2],'x');