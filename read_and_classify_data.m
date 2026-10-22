function [CNN_probabilities, epilept_probs, artifact_samples_all, bad_chan_idx] = read_and_classify_data(subj_num, data_dir)
nets = load('/net/sigma/fishpool3/projects3/EPIHFO/EPIHFO/seegartifacts/LOSO/LOSO_results.mat');
patients = [12,19,20,21,22,23,24,25,26,28,27,29,30,31,32,33,34,35,36,37,38,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60];
convnet = nets.results{patients == subj_num}.net;
data_files = {""};
user_segment_duration = [];
%% Start the program
fprintf(2,'======================================================================================\n');
fprintf(2,'=                                    Program Start                                   =\n');
fprintf(2,'======================================================================================\n');
fprintf("Processing data from subject number %d\n", subj_num);

%% Checking data and file directories
fprintf(2,'\n======                    Checking data and file directories                    ======\n');
[data_dir, edf_filename] = check_dir(data_dir, data_files);

%% Reading datetime range from excel

T = readtable("EPIHFO_start_end_times_badChannels_Milja_vs4.xlsx");
startTime = T.SleepStart(find(T.PatNRo == subj_num));   % find time from table
startTime = datestr(startTime, 'HH:MM:SS');
hdr = MemReadEDF(fullfile(data_dir, edf_filename(1)));
startDate = hdr.StartDate;                              % date of first file (evening or night)
startTime = datetime([startDate ' ' startTime], 'InputFormat', 'dd.MM.yy HH:mm:ss');    % combine date and time

hdr = MemReadEDF(fullfile(data_dir, edf_filename(end))); % date of the last file (morning)
endDate = hdr.StartDate; 
endTime = T.sleepEnd(find(T.PatNRo == subj_num));   % find time from table
endTime = datestr(endTime,'HH:MM:SS');
endTime = datetime([endDate ' ' endTime], 'InputFormat','dd.MM.yy HH:mm:ss');   % combine date and time
user_datetime_range = { ...
    datestr(startTime, 'dd-mmm-yyyy HH:MM:SS'), ...
    datestr(endTime, 'dd-mmm-yyyy HH:MM:SS') ...
};

fprintf(2,'\n======                        Checking the datetime range                       ======\n');
user_datetime_range = check_datetime(user_datetime_range);

%% Find, list, and sort the edf files of the selected subject
fprintf(2,'\n======                      The list of available edf files                     ======\n');
[data_length, sampling_rate, start_datetime, end_datetime, user_datetime_range, edf_filename] = check_files(data_dir, edf_filename, user_datetime_range);

%% Process the edf files based on the user-defined datetime range
fprintf(2,'\n======       The processed list of edf files based on the datetime range        ======\n');
[edf_filename, start_datetime, end_datetime, sampling_rate, sample_window, num_edf_files] = exclude_files(edf_filename, user_datetime_range, start_datetime, end_datetime, data_length, sampling_rate);
%% Extracting bad channels
[~,~, label, ~] = check_data(data_dir, edf_filename(1));
[~, bipo_inds, ~] = bipolar_montage_indices(label); % get montage indices
bipolar_labels = lower(string([char(label{bipo_inds(:,1)}) ...
        repelem('-',length(bipo_inds),1) char(label{bipo_inds(:,2)})])); % Cover unipolar labels to bipolar
bipolar_labels = erase(bipolar_labels,' ');         
badchans_raw = T.ChWithArtefacts(find(T.PatNRo == subj_num));   % raw cell value
badchans = extract_bad_channels(badchans_raw);
bad_channel_idx = ismember(lower(bipolar_labels), badchans);
bad_chan_idx = find(bad_channel_idx == 1); % row indices of bad channels

%% Checking the signal segmentation mode
fprintf(2,'======                      Checking the segmentation mode                      ======\n');
segment_sample_window = check_segmentation(edf_filename, user_segment_duration, sample_window, sampling_rate);

%% Intialize variables
seizure_time_overflow_start = 0;          % seizure time overflows starts to the current file from other files
seizure_time_overflow_end = 0;            % seizure time overflows ends to the current file from other files

%% Main Script applied to each subject's record separately
fprintf(2,'--------------------------------------------------------------------------------------\n');
for file_number = 1:num_edf_files % iterate through the subject's included files/recordings
    % Logic flages to check if accessing a prior file is needed
    looped_already = false;
    %% Checking data and annotations from the edf file
    idx = file_number - 1.*looped_already; % determine the index of the file to be handled
    file_name = edf_filename(idx);  % get the edf filename
    fprintf(2,'======        Checking data and annotations in file "%s"        ======\n', file_name);
    [fs, N, label, events] = check_data(data_dir, file_name);

    %% Applying the CNN pipeline
    fprintf(2,'\n======                 Applying the automatic detection pipeline                ======\n');        
    num_segments = size(segment_sample_window{idx},2);
    for seg_num = 1:num_segments
        if num_segments == 1
            fprintf('--- Loading the entire requested duration ---\n');
        else
            fprintf('--- Loading segment %d/%d from the edf file ---\n', seg_num, num_segments);
        end
        data = edfread_with_range(fullfile(data_dir, file_name), segment_sample_window{idx}(:,seg_num), segment_sample_window{idx}(2,end));

        disp('--- Preprocessing ---');
        data = uni2bi_montage(data', label);                  % convert the data to the bipolar montage
        data.x_bip = data.x_bip';
        data_original = data.x_bip;

        artefact_samples = extract_artefact_locations(events, N, fs); % Search for the artefact samples in the file (MA updated)
        artefact_samples = artefact_samples + shift;
        shift = shift + size(data_original,1);
        artifact_samples_all = [artifact_samples_all; artefact_samples];

        %% Use CNN to find artefacts with all the different CNNs
        fprintf(2,"=====    Classify segments using CNN    ======\n")
    
        new_fs = 5000;
        windowSize = new_fs*3; % samples per segment 
        overlap = 0; % 
        step = windowSize - overlap; 
        numSegments = floor((size(data_original,1) - 3*fs) / (3*fs))+1;
        [b,a] = butter(3, 900/(0.5*new_fs), 'low');
        
        CNN_cell = cell(n,1);
        epilept_cell = cell(n,1);

        %% prepare the data
        for ch = 1:size(data_original, 2)
            broad     = filtfilt(b,a,resample(data_original(:,ch),new_fs,fs));
            beta      = BpPowerEnvelope(resample(data_original(:,ch),new_fs,fs), 20, 100, new_fs);
            gamma     = BpPowerEnvelope(resample(data_original(:,ch),new_fs,fs), 80, 250, new_fs);
            high      = BpPowerEnvelope(resample(data_original(:,ch),new_fs,fs), 200, 600, new_fs);
            ultrahigh = BpPowerEnvelope(resample(data_original(:,ch),new_fs,fs), 500, 900, new_fs);
            
            % preallocate 4D batch: [rows, cols, channels, numSegments]
            allSegments = zeros(5, windowSize, 1, numSegments);
        
            for i = 1:numSegments
                startIdx = (i-1)*step + 1;
                endIdx   = startIdx + windowSize - 1;
                allSegments(1,:,1,i) = zscore(broad(startIdx:endIdx));
                allSegments(2,:,1,i) = zscore(beta(startIdx:endIdx));
                allSegments(3,:,1,i) = zscore(gamma(startIdx:endIdx));
                allSegments(4,:,1,i) = zscore(high(startIdx:endIdx));
                allSegments(5,:,1,i) = zscore(ultrahigh(startIdx:endIdx));
            end
    
            %% classify data with all CNNs
            probs = predict(convnet, allSegments); 
            CNN_cell{ind}(ch,:) = probs(:,1)';
            epilept_cell{ind}(ch,:) = probs(:,3)';
        end
            % combine with previous files (if any)
        if file_number > 1 
            CNN_probabilities = [CNN_probabilities, CNN_cell];
            epilept_probs = [epilept_probs, epilept_cell];
        else
            CNN_probabilities = CNN_cell;
            epilept_probs = epilept_cell;
        end
    end
end

artifact_samples_all = artifact_samples_all / fs;

