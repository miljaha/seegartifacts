subj_nums = [12,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,40,41,42,43,44,45,46,47,48,50,51,52,53,54,55,56,57,58,59,60];         % Subject number
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
    for file_number = 1:num_edf_files % iterate through the subject's included files/recordings
        %% Checking data and annotations from the edf file
        idx = file_number; % determine the index of the file to be handled
        file_name = edf_filename(idx);  % get the edf filename
        fprintf(2,'======        Checking data and annotations in file "%s"        ======\n', file_name);
        [fs, N, label, events] = check_data(data_dir, file_name);

        % get bad channels
        [bad_channel_mask, bipolar_labels, include_channel_idx, exclude_channel_idx] = exclude_channels(subj_num, label);
        artefact_samples = extract_artefact_locations(events, N, fs); % search for the artefact samples in the file

        %% Define artefact periods to load
        num_segments = size(artefact_samples,1);
        for seg_num = 1:num_segments
            if num_segments == 1
                fprintf('--- Loading the entire requested duration ---\n');
            else
                fprintf('--- Loading segment %d/%d from the edf file ---\n', seg_num, num_segments);
            end
            
            n_segments_3s = ceil((artefact_samples(seg_num,2) - artefact_samples(seg_num,1)) / window_size);
            extra_length = round((n_segments_3s*window_size - (artefact_samples(seg_num,2) - artefact_samples(seg_num,1))) / 2);

            read_start = artefact_samples(seg_num,1) - extra_length;
            read_end = artefact_samples(seg_num,2) + extra_length;
            if read_start <= 0
                read_start = 1;
                read_end = artefact_samples(seg_num,2) + 2*extra_length;
            elseif read_end > segment_sample_window{idx}(2,end)
                read_end = segment_sample_window{idx}(2,end);
                read_start = artefact_samples(seg_num,1) - 2*extra_length;
            end

            data = edfread_with_range(fullfile(data_dir, file_name), [read_start,read_end],read_end);
            disp('--- Preprocessing ---');
            data = uni2bi_montage(data', label);                  % convert the data to the bipolar montage

            badchannel_data = data.x_bip(bad_channel_mask,:);     % pick only bad channels
            for c = 1:sum(bad_channel_mask)
                broad = filtfilt(b,a,resample(badchannel_data(c,:),new_fs,fs));
                beta = BpPowerEnvelope(resample(badchannel_data(c,:),new_fs,fs), 20, 100, new_fs);
                gamma = BpPowerEnvelope(resample(badchannel_data(c,:),new_fs,fs), 80, 250, new_fs);
                high = BpPowerEnvelope(resample(badchannel_data(c,:),new_fs,fs), 200, 600, new_fs);
                ultrahigh = BpPowerEnvelope(resample(badchannel_data(c,:),new_fs,fs), 500, 900, new_fs);

                for t = 1:n_segments_3s
                    s = (t-1)*window_size_new + 1;
                    e = t*window_size_new;
                    
                    segment = zeros(5,window_size_new);
                    segment(1,:) = zscore(broad(s:e)); %Bandpass envelopes 
                    segment(2,:) = zscore(beta(s:e)); 
                    segment(3,:) = zscore(gamma(s:e)); 
                    segment(4,:) = zscore(high(s:e)); 
                    segment(5,:) = zscore(ultrahigh(s:e));

                    probs = predict(convnet, segment); 
                    if probs(1) > 0.8
                        extracted_samples(:,:,end+1) = segment;
                    end
                end
            end


            % n_artefact_segments = ceil(size(data.x_bip,2) / window_size) * sum(bad_channel_mask);
            % n_artefact_segments_sum = n_artefact_segments_sum + n_artefact_segments;

        end
    end
    fprintf("Total artefacts found: %d\n", n_artefact_segments_sum)
end