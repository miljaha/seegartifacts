load("lastpatient.mat")
load("extracted_good_samples.mat")
nextpatient = i+1;
%%
subj_nums = [12,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60];         % Subject number
% find files automatically, extract artefacts and bad channels, load
% artefact times only
data_files = {""};
user_datetime_range = {"",""};
user_segment_duration = [];
window_size = 3*2048;
n_artefact_segments_sum = 0;
extracted_samples = zeros(5,15000,0);
new_fs = 5000;
window_size_new = 3*new_fs;
load("convnet.mat")
patient_number = [];
starts = [];

[b,a] = butter(3, 900/(0.5*new_fs), 'low');
for i = 1:length(subj_nums)
    subj_num = subj_nums(i);
    fprintf("Starting subject %d\n",subj_num)

    data_dir = "/projects3/EPIHFO/EPIHFO/Pat" + string(subj_num);
    [data_dir, edf_filename] = check_dir(data_dir, data_files);

    %% Checking the input datetime range
    fprintf(2,'\n======                        Checking the datetime range                       ======\n');
    user_datetime_range = check_datetime(user_datetime_range);
    
    %% Find, list, and sort the edf files of the selected subject
    fprintf(2,'\n======                      The list of available edf files                     ======\n');
    [data_length, sampling_rate, start_datetime, end_datetime, user_datetime_range, edf_filename] = check_files(data_dir, edf_filename, user_datetime_range);
    
    %% Process the edf files based on the user-defined datetime range
    fprintf(2,'\n======       The processed list of edf files based on the datetime range        ======\n');
    [edf_filename, start_datetime, end_datetime, sampling_rate, sample_window, num_edf_files] = exclude_files(edf_filename, user_datetime_range, start_datetime, end_datetime, data_length, sampling_rate);
    
    %% Checking the signal segmentation mode
    fprintf(2,'======                      Checking the segmentation mode                      ======\n');
    segment_sample_window = check_segmentation(edf_filename, user_segment_duration, sample_window, sampling_rate);
    
    %% Intialize variables
    seizure_time_overflow_start = 0;          % seizure time overflows starts to the current file from other files
    seizure_time_overflow_end = 0;            % seizure time overflows ends to the current file from other files
    all_labels      = cell(1,num_edf_files);  % cell array holding the good channel labels from all recordings
    all_bad_labels  = cell(1,num_edf_files);  % cell array holding the bad channel labels from all recordings
    all_info        = cell(1,num_edf_files);  % cell array holding the recordings info
    all_rates       = cell(1,num_edf_files);  % cell array holding the rates from all recordings
    
    %% Main Script applied to each subject's record separately
    fprintf(2,'--------------------------------------------------------------------------------------\n');
    file_number = 1; % only take the first recording 
    %% Checking data and annotations from the edf file
    idx = file_number; % determine the index of the file to be handled
    file_name = edf_filename(idx);  % get the edf filename
    fprintf(2,'======        Checking data and annotations in file "%s"        ======\n', file_name);
    [fs, N, label, events] = check_data(data_dir, file_name);

    % get bad channels
    [~, bipo_inds, ~] = bipolar_montage_indices(label); % get montage indices
    bipolar_labels = lower(string([char(label{bipo_inds(:,1)}) ...
        repelem('-',length(bipo_inds),1) char(label{bipo_inds(:,2)})])); % Cover unipolar labels to bipolar
    bipolar_labels = erase(bipolar_labels,' ');                 

    T = readtable("EPIHFO_start_end_times_badChannels_Milja_vs4.xlsx");
    badchans_raw = T.ChWithArtefacts(find(T.PatNRo == subj_num));   % raw cell value
    badchans = extract_bad_channels(badchans_raw);
    bad_channel_mask = ismember(lower(bipolar_labels), badchans);

    artefact_samples = extract_artefact_locations(events, N, fs); % search for the artefact samples in the file
    artefact_samples_newfs = artefact_samples .* (new_fs/fs);
    
    data = edfread_with_range(fullfile(data_dir, file_name), segment_sample_window{idx}(:,1), segment_sample_window{idx}(2,end));
    disp('--- Preprocessing ---');
    data = uni2bi_montage(data', label);                  % convert the data to the bipolar montage

    data.x_bip = data.x_bip(~bad_channel_mask,:);     % exclude bad channels
    
    for c = 1:size(data.x_bip,1)
        n_per_c = 0;
        fprintf("Starting channel %d\n",c)
        broad = filtfilt(b,a,resample(data.x_bip(c,:),new_fs,fs));
        beta = BpPowerEnvelope(resample(data.x_bip(c,:),new_fs,fs), 20, 100, new_fs);
        gamma = BpPowerEnvelope(resample(data.x_bip(c,:),new_fs,fs), 80, 250, new_fs);
        high = BpPowerEnvelope(resample(data.x_bip(c,:),new_fs,fs), 200, 600, new_fs);
        ultrahigh = BpPowerEnvelope(resample(data.x_bip(c,:),new_fs,fs), 500, 900, new_fs);

        t = 1;
        end_of_data = false;
        
        while ~end_of_data && n_per_c < 100
            s = (t-1)*window_size_new + 1;
            e = t*window_size_new;
        
            if e > size(broad,2)
                end_of_data = true;
                continue;
            end
        
            overlaps = artefact_samples_newfs(:,1) <= e & artefact_samples_newfs(:,2) >= s;
        
            if any(overlaps)
                last_artefact_end = max(artefact_samples_newfs(overlaps,2));
                t = ceil(last_artefact_end / window_size_new) + 1;
            else
                segment = zeros(5,window_size_new);
                segment(1,:) = zscore(broad(s:e));
                segment(2,:) = zscore(beta(s:e));
                segment(3,:) = zscore(gamma(s:e));
                segment(4,:) = zscore(high(s:e));
                segment(5,:) = zscore(ultrahigh(s:e));
        
                probs = predict(convnet, segment);
                if probs(1) > 0.5
                    extracted_samples(:,:,end+1) = segment;
                    patient_number(end+1) = subj_num;
                    starts(end+1) = (t-1)*3;
                    n_per_c = n_per_c + 1;
                end
                t = t + 1;
            end
        end
    end

    
    fprintf("Total samples found: %d\n", size(patient_number,2))
        % n_artefact_segments = ceil(size(data.x_bip,2) / window_size) * sum(bad_channel_mask);
        % n_artefact_segments_sum = n_artefact_segments_sum + n_artefact_segments;
    save("extracted_good_samples", "extracted_samples","-v7.3")
    save("lastpatient_good", "i")
    save("patient_number_good","patient_number","-v7.3")
    save("good_samples_starts", "starts","-v7.3")
end


