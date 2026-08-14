% Copyright (c) 2026 Mohammad Al-Sa'd & Päivi Nevalainen
%
% Permission is hereby granted, free of charge, to any person obtaining a
% copy of this software and associated documentation files (the "Software"),
% to deal in the Software without restriction, including without limitation
% the rights to use, copy, modify, merge, publish, distribute, sublicense,
% and/or sell copies of the Software, and to permit persons to whom the
% Software is furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included
% in all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
% OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
% THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
% DEALINGS IN THE SOFTWARE.
%
% Email: ext-mohammad.al-sad@hus.fi, paivi.nevalainen@hus.fi
%
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
%        HUS Automatic Detection Toolbox for Stimulation SEEG v3.1        
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
% <INPUTs>
% subj_num              : subject number, e.g, 18.
% data_dir              : directory where the edf data files exist.
% data_files            : selected set of edf files to be used, e.g.,
%                         {"EEG_204-export.edf","EEG_205-export.edf"} or
%                         {""} to automatically select all available files.
% user_datetime_range   : selected start and end datetime, e.g.,
%                         {"27-Nov-2019 09:20:00","3-5-2021 13:5:00"}
%                         or {"",""} to automatically select suitable range.
% requested_frequency   : selected stimulation frequency in Hz, e.g.,
%                         1, "5", or [] for the 1 Hz default option.
% requested_current     : selected stimulation current in mA, e.g.,
%                         4, "3", or [] for the default 5 mA option.
% user_measure          : selected detection measure, e.g., "R", ["FR","R"],
%                         or ["r","fr","s","sr","sfr","gs"] where "R" is 
%                         for Ripples, "FR" is for Fast-Ripples, "S" is for
%                         Spikes, "SR" is for Spike-Ripples, "SFR" is for 
%                         Spike-Fast-Ripples, and "GS" is for Gamma-Spikes.
%
% <OUTPUTs>
% out                   : program status in text.
%
% <Notes>
% This toolbox version supports:
% (1)  different sampling rates in each edf file.
% (2)  exact, non-exact, and empty datetime range selection.
% (3)  full-precision datetime computations.
% (4)  exact, non-exact, and empty data files selection.
% (5)  logging the screen outputs for remote support.
% (6)  finds and skips invalid annotations instances.
% (7)  custom edf reader with arbitrary time ranges.
% (8)  user-defined multi-measure selection and processing.
% (9)  saving detailed detection results in HDF5 format (currently disabled
%      becasue it is slow) and MAT format.
% (10) saving summary results in multiple Excel files.
% (11) optimized loading and processing of data.
% (12) various input datetime formats.
% (13) automatic annotation extraction from internal files (.edf) and
%      external files (.xlsx, .xls, .csv, or .txt).
% (14) supports both serial and parallel operations.
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%

function out = automatic_detection_stimulation(subj_num, data_dir, data_files, user_datetime_range, requested_frequency, requested_current, user_measure)
%% Start the program
diary off; % close any open log files
diary_file_str = "diary_pat" + string(subj_num) + ".txt"; % initialize the diary filename
if exist(diary_file_str, 'file') > 0 % check if an older log file exists and delete it
    delete(diary_file_str);
end
diary(diary_file_str); % log the screen outputs in a diary
fprintf(2,'======================================================================================\n');
fprintf(2,'=                                    Program Start                                   =\n');
fprintf(2,'======================================================================================\n');
fprintf("Processing data from subject number %d\n", subj_num);
out = "The program has started";

%% Checking data and file directories
fprintf(2,'\n======                    Checking data and file directories                    ======\n');
[data_dir, edf_filename] = check_dir(data_dir, data_files);

%% Checking the input datetime range
fprintf(2,'\n======                        Checking the datetime range                       ======\n');
user_datetime_range = check_datetime(user_datetime_range);

%% Find, list, and sort the edf files of the selected subject
fprintf(2,'\n======                      The list of available edf files                     ======\n');
[data_length, sampling_rate, start_datetime, end_datetime, user_datetime_range, edf_filename] = check_files(data_dir, edf_filename, user_datetime_range);

%% Process the edf files based on the user-defined datetime range
fprintf(2,'\n======       The processed list of edf files based on the datetime range        ======\n');
[edf_filename, start_datetime, end_datetime, ~, sample_window, num_edf_files] = exclude_files(edf_filename, user_datetime_range, start_datetime, end_datetime, data_length, sampling_rate);

%% Checking the selected stimulation parameters
fprintf(2,'\n======               Checking the selected stimulation parameters               ======\n');
[requested_current, requested_frequency] = check_stim_parameters(requested_current, requested_frequency);

%% Checking the selected detection measure
fprintf(2,'\n======                 Checking the selected detection measures                 ======\n');
short_list_of_measures = ["r","fr","s","sr","sfr","gs"];
complete_list_of_measures = ["Ripples","Fast-Ripples","Spikes","Spike-Ripples",...
    "Spike-Fast-Ripples","Gamma-Spikes"];
user_measure = check_measure(user_measure, short_list_of_measures, complete_list_of_measures);

%% Main Script applied to each subject's record separately
fprintf(2,'--------------------------------------------------------------------------------------\n');
for file_number = 1:num_edf_files % iterate through the subject's included files/recordings
    %% Checking data and annotations from the edf file
    file_name = edf_filename(file_number);  % get the edf filename
    fprintf(2,'======        Checking data and annotations in file "%s"        ======\n', file_name);
    [fs, N, label, events] = check_data(data_dir, file_name);
    artefact_samples = extract_artefact_locations(events, N, fs); % search for the artefact samples in the file

    %% Extracting bad channels from the edf file
    fprintf(2,'\n======           Extracting bad channels in file "%s"           ======\n', file_name);
    [exclude_bad_channel_mask, bipolar_labels] = exclude_channels(subj_num, label);

    %% Processing stimulation information
    fprintf(2,'\n======                    Processing stimulation information                    ======\n');
    trigger_index = contains(lower(label),'mkr');                        % find trigger channels in data
    if any(trigger_index)                                                % check if a trigger signal exists
        [~, trigger_signal] = MemReadEDF(fullfile(data_dir, file_name), 'channels', find(trigger_index)); % load trigger signals
        fprintf('--- Trigger signal from file %s is loaded successfully ---\n', file_name);
        [trigger_signal, ch_stimulation_events, stimulation_details, ...
            stimulation_current, stimulation_frequency, requested_current_idx,...
            requested_frequency_idx, events] = get_stimulation_info(trigger_signal, label, ...
            events, bipolar_labels, requested_current, requested_frequency, sample_window(:,file_number)); % get available stimulation info
        if ~isempty(ch_stimulation_events) % do this if we have some annotation for stimulation otherwise skip this file
            fprintf('--- Annotation for stimulations is found ---\n');
            Summary = get_stimulation_details(trigger_signal, label, bipolar_labels, ...
                events, ch_stimulation_events, fs, sample_window(2,file_number), ...
                requested_frequency, requested_current, requested_current_idx, ...
                requested_frequency_idx, stimulation_details, ...
                stimulation_current, stimulation_frequency); % get summary details about stimulations
            start_cond = Summary.cycle_start_from_trigger < sample_window(1,file_number);  % Check if any cycle "actual" start is before the selected datetime
            end_cond   = Summary.cycle_end_from_trigger > sample_window(2,file_number);    % Check if any cycle "actual" end is after the selected datetime
            Summary(start_cond | end_cond, :) = []; % remove stimulation data outside the requested datetime range
            num_stimulations = size(Summary,1); % the number of valid stimulation data
        else
            warning("File " + file_name + " has no annotations for stimulations at " + ...
                requested_current + "mA/" + requested_frequency + "Hz! Skip to next file -->>");
            continue
        end
    else
        warning("File " + file_name + " has no trigger signal! Skip to next file -->>");
        continue
    end

    %% Applying the automatic detection pipeline
    fprintf(2,'\n======                 Applying the automatic detection pipeline                ======\n');   
    stimulus_removal_window = 20/1000;                % stimulus removal window in seconds
    thresh_perc = 0.1;                                % event and stimulus maximum permitted overlap ratio
    stimulus_pad_duration = round(0.1*fs);            % signal left side padding in samples (used for interpolation only)
    valid_channel_num = cell(1,num_stimulations);     % initialize the index of valid channels (not bad, stimulation, or neighbor)
    invalid_channel_num = cell(1,num_stimulations);   % initialize the index of invalid channels (bad, stimulation, or neighbor)    
    R_original   = cell(1,num_stimulations); FR_original  = cell(1,num_stimulations);
    IED_original = cell(1,num_stimulations); GS_original  = cell(1,num_stimulations);
    SR_original  = cell(1,num_stimulations); SFR_original = cell(1,num_stimulations);
    for stim_idx = 1:num_stimulations  % iterate through the stimulation cycles
        fprintf("Cycle %d:\n",stim_idx);
        fprintf('--- Loading the stimulation cycle ---\n');
        n_shift = sample_window(1,file_number) - 1;                                 % time shift for the cycle start
        n_start = Summary.cycle_start_from_trigger(stim_idx) - n_shift - stimulus_pad_duration;    % shifted cycle start time (0.1 second before is added to correctly interpolate)
        n_end   = Summary.cycle_end_from_trigger(stim_idx) - n_shift;               % shifted cycle end time
        if n_start < 1, error('Start time is very close to the first stimulus ( < 100ms)!'); end
        data = edfread_with_range(fullfile(data_dir, file_name), [n_start; n_end], n_end); % load requested data
        data = uni2bi_montage(data', label); % convert the data to the bipolar montage
        x = data.x_bip;
        disp('--- Preprocessing ---');
        %%% Exclude stimulation and neighboring channels
        ch_idx = 1:size(bipolar_labels,1);                                          % initialize the channel array
        exclude_channel_mask = exclude_bad_channel_mask;                            % get mask for bad channels
        exclude_channel_mask(Summary.stimulation_channel_number(stim_idx)) = true;  % find stimulation channel
        exclude_channel_mask(Summary.neighbor_channel_number{stim_idx}) = true;     % find neighbor channels
        valid_channel_num{stim_idx} = ch_idx(~exclude_channel_mask);                % get the index of valid channels
        invalid_channel_num{stim_idx} = ch_idx(exclude_channel_mask);               % get the index of invalid channels
        x = x(~exclude_channel_mask,:);                                             % remove unwanted channels from data
        %%% Replace stimulus pulses with linear interpolates
        n_shift = sample_window(1,file_number) + n_start - 2;                       % time shift for the stimulus start
        r_start = Summary.stimulation_pulses_location{stim_idx} - (round(fs*stimulus_removal_window/2) + 1) - n_shift; % shifted stimulus start time
        r_end   = Summary.stimulation_pulses_location{stim_idx} + (round(fs*stimulus_removal_window/2) + 1) - n_shift; % shifted stimulus end time        
        exclude_samples_idx = arrayfun(@(s,e) s:e, r_start, r_end, 'UniformOutput', false); % get the stimulus samples
        exclude_samples_idx = [exclude_samples_idx{:}];
        x(:,exclude_samples_idx) = nan;  % make stimulus samples NaNs        
        x = fillmissing(x,"spline", 2);  % replace the inserted NaN values by interpolation
        x = x(:,(stimulus_pad_duration+1):end); % remove the extra time padding in 'stimulus_pad_duration'
        disp('--- Automatic detection ---');
        %%% Perform the detection using the requested detection measure
        r_start = r_start - stimulus_pad_duration; % remove the padding from the stimulus start time
        r_end   = r_end - stimulus_pad_duration;   % remove the padding from the stimulus end time
        if any(ismember(["r","sr"], user_measure)) % condition to calculate ripples
            temp = ripple_detector(x', fs); % detection            
            [temp, sz_org] = remove_events_near_stimulus(temp, r_start, r_end, stimulus_removal_window, fs, thresh_perc); % remove events near stimulus
            R_original{stim_idx} = temp; % concatenate results from each stimulation cycle
            fprintf('%d/%d valid Ripples are detected\n', size(temp,1), sz_org);
        end
        if any(ismember(["fr","sfr"], user_measure)) % condition to calculate fast-ripples
            temp = fast_ripple_detector(x', fs); % detection
            [temp, sz_org] = remove_events_near_stimulus(temp, r_start, r_end, stimulus_removal_window, fs, thresh_perc); % remove events near stimulus
            FR_original{stim_idx} = temp; % concatenate results from each stimulation cycle
            fprintf('%d/%d valid Fast-Ripples are detected\n', size(temp,1), sz_org);
        end
        if any(ismember(["s","sr","sfr","gs"], user_measure)) % condition to calculate spikes
            settings = '-h 50 -dec 200 -b 8';
            parallel_flag = true;
            Spikes = spike_detector_hilbert_v23(x', fs, settings, parallel_flag); % detection
            Spikes.pos = Spikes.pos(:).*fs;   % start in samples (rounding is removed on purpose)
            Spikes.dur = Spikes.dur(:).*fs;   % duration in samples (rounding is removed on purpose)
            temp_spikes = [Spikes.chan, nan(size(Spikes.chan)), Spikes.pos, Spikes.dur, nan(size(Spikes.chan))]; % gather all results (similar format to R and FR)
            if isempty(temp_spikes) % if no spikes were detected
                temp_spikes = zeros(0,5);
            end
            [temp_spikes, sz_org] = remove_events_near_stimulus(temp_spikes, r_start, r_end, stimulus_removal_window, fs, thresh_perc); % remove events near stimulus
            IED_original{stim_idx} = temp_spikes; % concatenate results from each stimulation cycle
            fprintf('%d/%d valid Spikes are detected\n', size(temp_spikes,1), sz_org);
        end
        if any(ismember("gs", user_measure)) % condition to calculate gamma-spikes
            if ~isempty(temp_spikes) % if we have detected spikes
                temp = gamma_detector(x', temp_spikes, fs, 0); % detection
                [temp, sz_org] = remove_events_near_stimulus(temp, r_start, r_end, stimulus_removal_window, fs, thresh_perc); % remove events near stimulus
                dump = [temp, nan(size(temp(:,1)))]; % gather all results (similar format to R and FR)
            else % if no spikes were detected
                temp = temp_spikes;
                dump = temp_spikes;
            end
            GS_original{stim_idx} = dump; % concatenate results from each stimulation cycle
            fprintf('%d/%d valid Gamma-Spikes are detected\n', size(temp,1), sz_org);            
        end
    end
    
    disp('--- Postprocessing ---');
    R_artefacts_removed   = cell(1,num_stimulations); FR_artefacts_removed  = cell(1,num_stimulations);
    IED_artefacts_removed = cell(1,num_stimulations); GS_artefacts_removed  = cell(1,num_stimulations);
    SR_artefacts_removed  = cell(1,num_stimulations); SFR_artefacts_removed = cell(1,num_stimulations);
    for stim_idx = 1:num_stimulations  % iterate through the stimulation cycles
        if any(ismember(["r","sr"], user_measure)) % condition to process ripples
            R_original{stim_idx}(:,3) = R_original{stim_idx}(:,3) + Summary.cycle_start_from_trigger(stim_idx) - 1;  % shift start time
            R_original{stim_idx}(:,1) = valid_channel_num{stim_idx}(R_original{stim_idx}(:,1));  % fix the detected channel numbers
            R_artefacts_removed{stim_idx} = exclude_samples(R_original{stim_idx}, artefact_samples, 0, 0); % remove artefact segments if overlap
        end
        if any(ismember(["fr","sfr"], user_measure)) % condition to process fast-ripples
            FR_original{stim_idx}(:,3) = FR_original{stim_idx}(:,3) + Summary.cycle_start_from_trigger(stim_idx) - 1;  % shift start time
            FR_original{stim_idx}(:,1) = valid_channel_num{stim_idx}(FR_original{stim_idx}(:,1));  % fix the detected channel numbers
            FR_artefacts_removed{stim_idx} = exclude_samples(FR_original{stim_idx}, artefact_samples, 0, 0); % remove artefact segments if overlap
        end
        if any(ismember(["s","sr","sfr","gs"], user_measure)) % condition to process spikes
            IED_original{stim_idx}(:,3) = IED_original{stim_idx}(:,3) + Summary.cycle_start_from_trigger(stim_idx) - 1;  % shift start time
            IED_original{stim_idx}(:,1) = valid_channel_num{stim_idx}(IED_original{stim_idx}(:,1));  % fix the detected channel numbers
            IED_artefacts_removed{stim_idx} = exclude_samples(IED_original{stim_idx}, artefact_samples, 0, 0); % remove artefact segments if overlap
        end
        if any(ismember("gs", user_measure)) % condition to process gamma-spikes
            GS_original{stim_idx}(:,3) = GS_original{stim_idx}(:,3) + Summary.cycle_start_from_trigger(stim_idx) - 1;  % shift start time
            GS_original{stim_idx}(:,1) = valid_channel_num{stim_idx}(GS_original{stim_idx}(:,1));  % fix the detected channel numbers
            GS_artefacts_removed{stim_idx} = exclude_samples(GS_original{stim_idx}, artefact_samples, 0, 0); % remove artefact segments if overlap
        end
        if any(ismember("sr", user_measure)) % condition to calculate spike-ripples
            N_buffer = 0.1*fs + 1;  % 100ms buffer
            SR_original{stim_idx} = find_spikes_in_ripples(R_original{stim_idx}, IED_original{stim_idx}, N_buffer);
            SR_artefacts_removed{stim_idx} = find_spikes_in_ripples(R_artefacts_removed{stim_idx}, IED_artefacts_removed{stim_idx}, N_buffer);
        end
        if any(ismember("sfr", user_measure)) % condition to calculate spike-fast-ripples
            N_buffer = 0.1*fs + 1;  % 100ms buffer
            SFR_original{stim_idx} = find_spikes_in_ripples(FR_original{stim_idx}, IED_original{stim_idx}, N_buffer);
            SFR_artefacts_removed{stim_idx} = find_spikes_in_ripples(FR_artefacts_removed{stim_idx}, IED_artefacts_removed{stim_idx}, N_buffer);
        end
    end
    %%% Collecting all available detections
    if any(ismember(["r","sr"], user_measure)) % condition to collect ripples
        Summary.R_original = R_original';
        Summary.R_artefacts_removed = R_artefacts_removed';        
    end
    if any(ismember(["fr","sfr"], user_measure)) % condition to collect fast-ripples
        Summary.FR_original = FR_original';
        Summary.FR_artefacts_removed = FR_artefacts_removed';
    end
    if any(ismember(["s","sr","sfr","gs"], user_measure)) % condition to collect spikes
        Summary.IED_original = IED_original';
        Summary.IED_artefacts_removed = IED_artefacts_removed';
    end
    if any(ismember("gs", user_measure)) % condition to collect gamma-spikes
        Summary.GS_original = GS_original';
        Summary.GS_artefacts_removed = GS_artefacts_removed';
    end
    if any(ismember("sr", user_measure)) % condition to collect spike-ripples
        Summary.SR_original = SR_original';
        Summary.SR_artefacts_removed = SR_artefacts_removed';
    end
    if any(ismember("sfr", user_measure)) % condition to collect spike-fast-ripples
        Summary.SFR_original = SFR_original';
        Summary.SFR_artefacts_removed = SFR_artefacts_removed';
    end

    %% Rate computations
    fprintf(2,'\n======                          Event rate computations                         ======\n');
    num_channels       = size(bipolar_labels,1);   % total number of channels
    R_appear_rate      = cell(1,num_stimulations);
    FR_appear_rate     = cell(1,num_stimulations);
    IED_appear_rate    = cell(1,num_stimulations);
    GS_appear_rate     = cell(1,num_stimulations);
    SR_appear_rate     = cell(1,num_stimulations);
    SFR_appear_rate    = cell(1,num_stimulations);
    R_occupancy_rate   = cell(1,num_stimulations);
    FR_occupancy_rate  = cell(1,num_stimulations);
    IED_occupancy_rate = cell(1,num_stimulations);
    GS_occupancy_rate  = cell(1,num_stimulations);
    SR_occupancy_rate  = cell(1,num_stimulations);
    SFR_occupancy_rate = cell(1,num_stimulations);
    duration_original  = zeros(1,num_stimulations);
    duration_artefacts_removed = zeros(1,num_stimulations);

    disp('--- Event rates ---');    
    for stim_idx = 1:num_stimulations  % iterate through the stimulation cycles
        fprintf("Cycle %d\n",stim_idx);
        % Calculate signal duration after/before artefact removal
        cycle_win = [Summary.cycle_start_from_trigger(stim_idx), Summary.cycle_end_from_trigger(stim_idx)];
        duration_original(stim_idx) = (cycle_win(2) - cycle_win(1))/fs;
        duration_artefacts_removed(stim_idx) = remaining_duration(cycle_win, artefact_samples, duration_original(stim_idx), fs);
        % Calculate event rates (per second) and percentages of occupancy for each channel
        if any(ismember("r", user_measure)) % condition to calculate ripple rates
            [R_appear_rate{stim_idx}, R_occupancy_rate{stim_idx}] = occurance_occupancy_rate(num_channels, invalid_channel_num{stim_idx}, fs, ...
                {R_original{stim_idx}, R_artefacts_removed{stim_idx}},{duration_original(stim_idx), duration_artefacts_removed(stim_idx)});
            R_appear_rate{stim_idx} = R_appear_rate{stim_idx}./60;
        end
        if any(ismember("fr", user_measure)) % condition to calculate fast-ripple rates
            [FR_appear_rate{stim_idx}, FR_occupancy_rate{stim_idx}] = occurance_occupancy_rate(num_channels, invalid_channel_num{stim_idx}, fs, ...
                {FR_original{stim_idx}, FR_artefacts_removed{stim_idx}},{duration_original(stim_idx), duration_artefacts_removed(stim_idx)});
            FR_appear_rate{stim_idx} = FR_appear_rate{stim_idx}./60;
        end
        if any(ismember("s", user_measure)) % condition to calculate spike rates
            [IED_appear_rate{stim_idx}, IED_occupancy_rate{stim_idx}] = occurance_occupancy_rate(num_channels, invalid_channel_num{stim_idx}, fs, ...
                {IED_original{stim_idx}, IED_artefacts_removed{stim_idx}},{duration_original(stim_idx), duration_artefacts_removed(stim_idx)});
            IED_appear_rate{stim_idx} = IED_appear_rate{stim_idx}./60;
        end
        if any(ismember("sr", user_measure)) % condition to calculate spike-ripple rates
            [SR_appear_rate{stim_idx}, SR_occupancy_rate{stim_idx}] = occurance_occupancy_rate(num_channels, invalid_channel_num{stim_idx}, fs, ...
                {SR_original{stim_idx}, SR_artefacts_removed{stim_idx}},{duration_original(stim_idx), duration_artefacts_removed(stim_idx)});
            SR_appear_rate{stim_idx} = SR_appear_rate{stim_idx}./60;
        end
        if any(ismember("sfr", user_measure)) % condition to calculate spike-fast-ripple rates
            [SFR_appear_rate{stim_idx}, SFR_occupancy_rate{stim_idx}] = occurance_occupancy_rate(num_channels, invalid_channel_num{stim_idx}, fs, ...
                {SFR_original{stim_idx}, SFR_artefacts_removed{stim_idx}},{duration_original(stim_idx), duration_artefacts_removed(stim_idx)});
            SFR_appear_rate{stim_idx} = SFR_appear_rate{stim_idx}./60;
        end
        if any(ismember("gs", user_measure)) % condition to calculate gamma-spike rates
            [GS_appear_rate{stim_idx}, GS_occupancy_rate{stim_idx}] = occurance_occupancy_rate(num_channels, invalid_channel_num{stim_idx}, fs, ...
                {GS_original{stim_idx}, GS_artefacts_removed{stim_idx}},{duration_original(stim_idx), duration_artefacts_removed(stim_idx)});
            GS_appear_rate{stim_idx} = GS_appear_rate{stim_idx}./60;
        end
    end

    disp('--- Collecting all available rates ---');
    if any(ismember(["r","sr"], user_measure)) % condition to collect ripple rates
        Summary.R_appear_rate_original = cellfun(@(x) x(:,1), R_appear_rate, 'UniformOutput', false)';
        Summary.R_appear_rate_artefacts_removed = cellfun(@(x) x(:,2), R_appear_rate, 'UniformOutput', false)';
        Summary.R_occupancy_rate_original = cellfun(@(x) x(:,1), R_occupancy_rate, 'UniformOutput', false)';
        Summary.R_occupancy_rate_artefacts_removed = cellfun(@(x) x(:,2), R_occupancy_rate, 'UniformOutput', false)';
    end
    if any(ismember(["fr","sfr"], user_measure)) % condition to collect fast-ripple rates
        Summary.FR_appear_rate_original = cellfun(@(x) x(:,1), FR_appear_rate, 'UniformOutput', false)';
        Summary.FR_appear_rate_artefacts_removed = cellfun(@(x) x(:,2), FR_appear_rate, 'UniformOutput', false)';
        Summary.FR_occupancy_rate_original = cellfun(@(x) x(:,1), FR_occupancy_rate, 'UniformOutput', false)';
        Summary.FR_occupancy_rate_artefacts_removed = cellfun(@(x) x(:,2), FR_occupancy_rate, 'UniformOutput', false)';
    end
    if any(ismember(["s","sr","sfr","gs"], user_measure)) % condition to collect spike rates
        Summary.IED_appear_rate_original = cellfun(@(x) x(:,1), IED_appear_rate, 'UniformOutput', false)';
        Summary.IED_appear_rate_artefacts_removed = cellfun(@(x) x(:,2), IED_appear_rate, 'UniformOutput', false)';
        Summary.IED_occupancy_rate_original = cellfun(@(x) x(:,1), IED_occupancy_rate, 'UniformOutput', false)';
        Summary.IED_occupancy_rate_artefacts_removed = cellfun(@(x) x(:,2), IED_occupancy_rate, 'UniformOutput', false)';
    end
    if any(ismember("gs", user_measure)) % condition to collect gamma-spike rates
        Summary.GS_appear_rate_original = cellfun(@(x) x(:,1), GS_appear_rate, 'UniformOutput', false)';
        Summary.GS_appear_rate_artefacts_removed = cellfun(@(x) x(:,2), GS_appear_rate, 'UniformOutput', false)';
        Summary.GS_occupancy_rate_original = cellfun(@(x) x(:,1), GS_occupancy_rate, 'UniformOutput', false)';
        Summary.GS_occupancy_rate_artefacts_removed = cellfun(@(x) x(:,2), GS_occupancy_rate, 'UniformOutput', false)';
    end
    if any(ismember("sr", user_measure)) % condition to collect spike-ripple rates
        Summary.SR_appear_rate_original = cellfun(@(x) x(:,1), SR_appear_rate, 'UniformOutput', false)';
        Summary.SR_appear_rate_artefacts_removed = cellfun(@(x) x(:,2), SR_appear_rate, 'UniformOutput', false)';
        Summary.SR_occupancy_rate_original = cellfun(@(x) x(:,1), SR_occupancy_rate, 'UniformOutput', false)';
        Summary.SR_occupancy_rate_artefacts_removed = cellfun(@(x) x(:,2), SR_occupancy_rate, 'UniformOutput', false)';
    end
    if any(ismember("sfr", user_measure)) % condition to collect spike-fast-ripple rates
        Summary.SFR_appear_rate_original = cellfun(@(x) x(:,1), SFR_appear_rate, 'UniformOutput', false)';
        Summary.SFR_appear_rate_artefacts_removed = cellfun(@(x) x(:,2), SFR_appear_rate, 'UniformOutput', false)';
        Summary.SFR_occupancy_rate_original = cellfun(@(x) x(:,1), SFR_occupancy_rate, 'UniformOutput', false)';
        Summary.SFR_occupancy_rate_artefacts_removed = cellfun(@(x) x(:,2), SFR_occupancy_rate, 'UniformOutput', false)';
    end

    %% Export detailed detections to MAT and HDF5 formats
    fprintf(2,'\n======               Save detections for file "%s"              ======\n', file_name);
    if ~exist(fullfile(data_dir,"Detection Results"),"dir"), mkdir(fullfile(data_dir,"Detection Results")); end
    detections_format = ["channel number","frequency or nan","start sample","duration in samples","amplitude or nan"];
    notes = "The IED start and sample durations are not rounded. This affects also SR and SFR detections";
    bipolar_channels = upper(bipolar_labels);
    sampling_rate = fs;
    bad_channels = upper(bipolar_labels(exclude_bad_channel_mask));
    matfile = fullfile(data_dir,"Detection Results", string(erase(file_name, ".edf")) + "_stimulation_detections_at_" + ...
        requested_frequency + "Hz_" + requested_current + "mA_" + strjoin(user_measure,"_") + ".mat");
    if file_number == 1 && exist(matfile,'file') > 0, delete(matfile); end % check if an older file exists and delete it
    save(matfile,'Summary','sampling_rate','detections_format','notes','bipolar_channels','bad_channels');
    fprintf('File "%s" is saved successfully ...\n', string(erase(file_name, ".edf")) + "_stimulation_detections_at_" + ...
        requested_frequency + "Hz_" + requested_current + "mA_" + strjoin(user_measure,"_") + ".mat");
    % hd5file = fullfile(data_dir,"Detection Results", string(erase(file_name, ".edf")) + "_stimulation_detections_at_" + ...
    %     requested_frequency + "Hz_" + requested_current + "mA_" + strjoin(user_measure,"_") + ".hd5");
    % if file_number == 1 && exist(hd5file,'file') > 0, delete(hd5file); end % check if an older file exists and delete it
    % save_hdf5(hd5file, Summary, sampling_rate, detections_format, notes, bipolar_channels, bad_channels);
    % fprintf('File "%s" is saved successfully ...\n', string(erase(file_name, ".edf")) + "_stimulation_detections_at_" + ...
    %     requested_frequency + "Hz_" + requested_current + "mA_" + strjoin(user_measure,"_") + ".hd5");

    %% Export summary results to an Excel file
    fprintf(2,'\n======                Export rates for file "%s"                ======\n', file_name);   
    info{1,1} = file_name;
    info{2,1} = string(start_datetime(file_number));
    info{3,1} = string(end_datetime(file_number));
    info{4,1} = requested_frequency;
    info{5,1} = requested_current;
    info{6,1} = num_stimulations;
    info{7,1} = "NaN" + " denotes stimulation channels";
    info{8,1} = "NaN" + " denotes neighbore channels";
    info{9,1} = "NaN" + " denotes bad channels";
    if ~exist(fullfile(data_dir,"Excel Results"),'dir'), mkdir(fullfile(data_dir,"Excel Results")); end

    for i = 1:length(user_measure)
        save_status = false;
        max_attempts = 10;
        attempt = 0;
        while ~save_status && attempt < max_attempts
            attempt = attempt + 1;
            try
                excelfile = fullfile(data_dir,"Excel Results","stimulation_detections_pat" + subj_num + "_" + ...
                    requested_frequency + "Hz_" + requested_current + "mA_" + user_measure(i) + ".xlsx");
                if file_number == 1 && exist(excelfile,'file') > 0, delete(excelfile); end % check if an older file exists and delete it
                export_stimulations_to_excel(excelfile, info, bipolar_channels, ...
                    user_measure(i), Summary, exclude_bad_channel_mask, ...
                    sample_window(1,file_number), fs, start_datetime(file_number), ...
                    duration_original, duration_artefacts_removed);
                save_status = true;
            catch ME
                fprintf("Saving attempt %d/%d failed!\n", attempt, max_attempts);
                fprintf("Reason: %s\n",ME.message);
                fprintf("Re-Saving\n");
                pause(1);
            end
        end
        if ~save_status
            error("File could not be saved after %d attempts!", max_attempts);
        end
    end
end
out = "The program has finished";
diary off; % close the log file
end