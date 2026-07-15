% Multi-Subject Utility
% % Input Parameters

% Subjects to be analysed in a loop
subj_nums = [50,52,53,56,58,59,60];         % Subject number
% 51, 54, 55 ja 57 odottaa Päivin merkintöjä
% [12,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,40,41,42,43,44,45,46,47,48]
% done

% Maximum and minumum length of data procesed at once. You can edit these
% depending on the computer you use, longer max length of segment makes the
% processing faster, but too long segment will crash MATLAB if computer
% doesn't have enough RAM. Keep min over 5 mins due to background
% calculation. Basically, all segments will be the max length and then the
% remaining time, but if remaining time would be under minimum, then the
% last segment is max + remaining.

max_length_mins = 15;
min_length_mins = 5;
%%
logname = sprintf("analysis_log_%s.txt", datestr(now,'yyyymmdd_HHMMSS'));
diary(logname);
diary on;
% Function calling in a loop
for i = 1:length(subj_nums)
    try
        fprintf("Starting subject %d\n",subj_nums(i))
        data_dir = "/projects3/EPIHFO/EPIHFO/Pat" + string(subj_nums(i));
        edfFiles = {""}; % automatic selection

        z = run_detections(subj_nums(i), data_dir, ...
            edfFiles,max_length_mins, min_length_mins);
        fprintf("Subject %d complete, moving to next subject\n",subj_nums(i))
    catch ME
        fprintf("!!! ERROR for subject %d !!!\n", subj_nums(i));
        fprintf("Message: %s\n", ME.message);
        fprintf("Continuing to next subject...\n\n");
    end   
end
fprintf("\nAll subjects analysed! :)\n")
diary off;

function out = run_detections(subj_num,data_dir,data_files,max_length_mins, min_length_mins)
%
fprintf(2,'\n======                    Checking data and file directories                    ======\n');
if exist(data_dir,"file") > 0  % check if the data directory exists
    F = dir(fullfile(data_dir, "*.edf"));    % list all edf files in the subject's directory
    edf_filename = string({F.name}');        % gather all edf filenames
    if isempty(edf_filename) % check if there is any EDF files in the directory
        error('There are no EDF files in the selected directory!');
    else
        data_files = string(data_files);
        if ~(length(data_files) == 1 && strcmp(data_files(1),"")) % check if data file selection is auto or manual
            fprintf('Data file selection mode is manual\n');
            temp = intersect(data_files,edf_filename); % get subset of edf filenames
            if isempty(temp) % check if the selected files exist
                error('The selected EDF files do not exist in the selected directory!');
            else
                file_cond = ismember(data_files,temp); % check which files dont exist
                for i = 1:length(data_files)
                    fprintf('The data file "%s"', data_files(i));
                    if file_cond(i)
                        fprintf(" is OK\n");
                    else
                        fprintf(2," does not exist!\n");
                    end
                end
                edf_filename = temp;
            end
        else
            fprintf('Data file selection mode is automatic\n');
        end
    end
else
   error('Data directory does not exist!');
end

% Define the datetime range as {sleep start, sleep start + 1h}
fprintf(2,'\n======                        Checking the datetime range                       ======\n');
T = readtable("EPIHFO_start_end_times_badChannels_Milja.xlsx");
startTime = T.SleepStart(find(T.PatNRo == subj_num));   % find time from table
startTime = datestr(startTime, 'HH:MM:SS');
hdr = MemReadEDF(fullfile(data_dir, edf_filename(1)));
startDate = hdr.StartDate;                              % date of first file (evening or night)
startTime = datetime([startDate ' ' startTime], 'InputFormat', 'dd.MM.yy HH:mm:ss');    % combine date and time
%startTime = erase(startTime, "(1. filen alku)");  % if needed, remove the parentheses text
%startTime = datetime(startTime, 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');

hdr = MemReadEDF(fullfile(data_dir, edf_filename(end))); % date of the last file (morning)
endDate = hdr.StartDate; 
endTime = T.sleepEnd(find(T.PatNRo == subj_num));   % find time from table
%endTime = erase(endTime , "(viimeisen filen loppu)");  % if needed, remove the parentheses text
endTime = datestr(endTime,'HH:MM:SS');
endTime = datetime([endDate ' ' endTime], 'InputFormat','dd.MM.yy HH:mm:ss');   % combine date and time
user_datetime_range = { ...
    datestr(startTime, 'dd-mmm-yyyy HH:MM:SS'), ...
    datestr(endTime, 'dd-mmm-yyyy HH:MM:SS') ...
};
user_datetime_range{1} = datetime(user_datetime_range{1});
user_datetime_range{2} = datetime(user_datetime_range{2});
if user_datetime_range{1} >= user_datetime_range{2}
    error('The start datetime must be less than the end datetime!');
end
if isnat(user_datetime_range{1}) && ~isnat(user_datetime_range{2})
    fprintf('The selected datetime range is earliest datetime - %s\n',user_datetime_range{2});
elseif ~isnat(user_datetime_range{1}) && isnat(user_datetime_range{2})
    fprintf('The selected datetime range is %s - latest datetime\n', ...
        user_datetime_range{1});
elseif isnat(user_datetime_range{1}) && isnat(user_datetime_range{2})
    fprintf('The selected datetime range is earliest datetime - latest datetime\n');
else
    fprintf('The selected datetime range is %s - %s\n',user_datetime_range{1},user_datetime_range{2});
end

% Find, list, and sort the EDF files of the selected subject
fprintf(2,'\n======                      The list of available EDF files                     ======\n');
datetime_format = 'dd-MMMM-yyyy HH:mm:ss.SSSSSSSSS';
num_edf_files  = size(edf_filename,1);   % number of available edf files in the subject's directory
data_length    = zeros(1,num_edf_files); % number of data samples in each edf file
sampling_rate  = zeros(1,num_edf_files); % sampling rate in each edf file
start_datetime = [];                     % variable to gather edf start datetime
end_datetime   = [];                     % variable to gather edf end datetime
for file_number = 1:num_edf_files        % iteratre through the subject's available edf files
    EDFhdr = MemReadEDF(fullfile(data_dir, edf_filename(file_number)));    % load the data to perform initial calculations (MA updated)
    data_length(file_number) = EDFhdr.NumSamples(1)*EDFhdr.NumRecords;     % number of data samples (MA updated)
    sampling_rate(file_number) = EDFhdr.SamplingRate(1); % sampling rate
    end_time = (data_length(file_number) - 1) / sampling_rate(file_number);   % duration of the edf file
    dt_str = strrep(EDFhdr.StartDate,".","-") + " " + strrep(EDFhdr.StartTime,".",":") + ".0"; % start datetime of the edf file in string format
    start_datetime = cat(1,start_datetime,datetime(dt_str,"InputFormat",'dd-MM-yy HH:mm:ss.S','Format',datetime_format)); % start datetime of the edf file
    end_datetime   = cat(1,end_datetime,start_datetime(file_number,:) + seconds(end_time)); % end datetime of the edf file
end
[start_datetime, file_cond] = sort(start_datetime); % sort the edf files according to their start datetime
edf_filename  = edf_filename(file_cond);            % rearrange the edf filenames
end_datetime  = end_datetime(file_cond);            % rearrange the edf end datetimes
data_length   = data_length(file_cond);             % rearrange the edf number of samples
sampling_rate = sampling_rate(file_cond);           % rearrange the edf sampling rates
disp(table(edf_filename,string(start_datetime),string(end_datetime), ...
    'VariableNames',{'Filename','Start date/time','End date/time'})); % display meta info
if isnat(user_datetime_range{1}) || user_datetime_range{1} < start_datetime(1)
    user_datetime_range{1} = start_datetime(1);
    fprintf('The start datetime is set at the earliest available ---\n');
end
if isnat(user_datetime_range{2}) || user_datetime_range{2} > end_datetime(end)
    user_datetime_range{2} = end_datetime(end);
    fprintf('The end datetime is set at the latest available ---\n');
end

% Process the EDF files based on the user-defined datetime range
% Exclude unnecessary EDF files
fprintf(2,'======       The processed list of EDF files based on the datetime range        ======\n');
cond1 = end_datetime < user_datetime_range{1};   % edf files with end datetime less than the user-defined start datetime
cond2 = start_datetime > user_datetime_range{2}; % edf files with start datetime more than the user-defined end datetime
cond  = cond1 | cond2;      % combined exclusion rule
edf_filename(cond)   = [];  % exclude unnecessary filenames
start_datetime(cond) = [];  % exclude unnecessary start datetime
end_datetime(cond)   = [];  % exclude unnecessary end datetime
data_length(cond)    = [];  % exclude unnecessary number of samples
sampling_rate(cond)  = [];  % exclude unnecessary sampling rates
% Process the start and end times of the included edf files
sample_window        = [ones(1,length(data_length)); data_length];           % the window of selected samples for each edf file
shift_in_start_time  = seconds(user_datetime_range{1} - start_datetime(1));  % shift in the start datetime
shift_in_end_time    = seconds(end_datetime(end) - user_datetime_range{2});  % shift in the end datetime
sample_window(1,1)   = floor(shift_in_start_time*sampling_rate(1) + 1);      % correct the first included edf start sample
sample_window(2,end) = sample_window(2,end) - floor(shift_in_end_time*sampling_rate(end) + 1) + 1;  % correct the last included edf end sample
start_datetime(1)    = max(start_datetime(1),user_datetime_range{1});   % correct the first included edf start datetime
end_datetime(end)    = min(end_datetime(end),user_datetime_range{2});   % correct the last included edf end datetime
num_edf_files        = size(edf_filename,1);                            % number of included edf files
disp(table(edf_filename,string(start_datetime),string(end_datetime), ...
    'VariableNames',{'Filename','Start date/time','End date/time'})); % display meta info
start_datetime.Format = datetime_format;
end_datetime.Format   = datetime_format;

% Intialize variables
seizure_time_overflow_start = 0;  % Seizure time overflows starts to the current file from other files
seizure_time_overflow_end = 0;    % Seizure time overflows ends to the current file from other files
all_labels    = {};               % Cell array holding the channel labels from all recordings
all_info      = {};               % Cell array holding the recordings info
all_rates     = {};               % Cell array holding the rates from all recordings
all_CNN_durations = [];

% check fs
file_name = edf_filename(1);
fs = sampling_rate(1); % get the edf file sampling rate
fprintf("Sampling frequency is %d Hz\n",fs);
max_length = max_length_mins*60*fs;            % min x sec x samples
min_length = min_length_mins*60*fs;
%
fprintf(2,"======       Beginning of analysis        ======\n")
% Main Script applied to each subject's record separately
for file_number = 1:num_edf_files % iteratre through the subject's included files/recordings
    % Logic flages to check if accessing a prior file is needed
    handle_file    = true;
    looped_already = false;

    CNN_artifacts_all = []; 

    while handle_file
        %% Loading and data extraction from EDF file
        idx = file_number - 1.*looped_already; % Determine the index of the file to be handled
        file_name = edf_filename(idx);
        fprintf(2,'======        Loading and data extraction from file "%s"        ======\n', file_name);
        [EDFhdr, data] = MemReadEDF(fullfile(data_dir, file_name), 'annotations'); % load data and annotations
        fs = EDFhdr.SamplingRate(1); % get the edf file sampling rate
        [N, M] = size(data);         % number of samples and channels
        label  = string(erase(EDFhdr.ChanLabel(1:M)',"POL ")); % remove "POL " from the channel labels
        events = EDFhdr.Annotations;   % get the annotations
        if any(isnan([events.sample])) % check for invalid markers (MA updated)
            warning("Some annotation markers are invalid!");
            events(isnan([events.sample])) = []; % remove invalid annotations (MA updated)
            disp('Removing invalid annotations is complete!');
        end
        fprintf('File %s is loaded successfully...\n', file_name);
        [~, bipo_inds, ~] = bipolar_montage_indices(label); % get montage indices

        %% Data preprocessing
        fprintf(2,'\n======                            Data preprocessing                            ======\n');
        bipolar_labels = lower(string([char(label{bipo_inds(:,1)}) ...
            repelem('-',length(bipo_inds),1) char(label{bipo_inds(:,2)})])); % Cover unipolar labels to bipolar
        bipolar_labels = erase(bipolar_labels,' ');                          % Remove any empty spaces if exists
        data = uni2bi_montage(data', label); % Convert the data to the bipolar montage (MA updated)
        data_original = data.x_bip;
        % Bad channels from table
        badchans_raw = T.ChWithArtefacts(find(T.PatNRo == subj_num));   % raw cell value
        badchans_raw = strtrim(string(badchans_raw));
        if badchans_raw == "-" || badchans_raw == ""
            bad_channel_idx = false(size(bipolar_labels));
        else
            badchans_raw = regexprep(badchans_raw, '\([^)]*\)', '');
            badchans = strtrim(split(badchans_raw, ','));
            badchans = regexprep(badchans, '-.*', '');
            badchans = regexprep(badchans, '([a-zA-Z]+)(\d)$', '$10$2');
            bad_channel_idx = contains(bipolar_labels, lower(string(badchans)) + "-");
        end
        % Manually marked artefacts & seizures
        artefact_samples = extract_artefact_locations(events, N, fs); % Search for the artefact samples in the file (MA updated)
        % Search for seziure samples in the file and gather buffered seizure timestamps from events
        [seizure_samples, overflow_start, overflow_end] = extract_seizure_locations(events, N, fs, ...
            seizure_time_overflow_start, seizure_time_overflow_end, ...
            looped_already, sample_window(1,idx), sample_window(2,idx));
        % combine artefact and seizure intervals
        both_samples = merge_intervals(seizure_samples, artefact_samples);
        % Save seizure time overflows (overflows at start -> Goes to PREVIOUS file)
        seizure_time_overflow_start = overflow_start;
        % Only saves the end overflow if not rehandling prior file
        % (overflows at end -> Goes to NEXT file)
        if ~looped_already, seizure_time_overflow_end = overflow_end; end
        % Extract the samples of interest
        sample_window_max = split_windows(sample_window(:,idx), max_length, min_length);
        duration_original = seconds(end_datetime(idx)-start_datetime(idx)); % in seconds

        for s = 1:size(sample_window_max,2)
            data.x_bip = data_original(:,sample_window_max(1,s):sample_window_max(2,s))';
            fprintf("Length of data: %.2f min\n", (size(data.x_bip,1))/fs/60);
            %% Use CNN to find alternative artefacts
            fprintf(2,"=====    Classify segments using CNN    ======\n")
    
            load('convnet.mat') 
            windowSize = fs*3; % samples per segment 
            overlap = 0; % 
            step = windowSize - overlap; 
            numSegments = floor((size(data.x_bip,1) - windowSize) / step)+1;
            segment_times = (0:numSegments-1) * (step/fs);
            [b,a] = butter(3, 900/(0.5*fs), 'low');
            CNN_artifacts = zeros(numSegments,size(data.x_bip,2));
         
            for ch = 1:size(data.x_bip, 2) % loop through channels (158) 
                signal = data.x_bip(:, ch); 
                for i = 1:numSegments 
                    startIdx = (i-1)*step + 1; 
                    endIdx = startIdx + windowSize - 1;
                    segment_raw = signal(startIdx:endIdx); 
                    segment = zeros(5, windowSize); % Lowpass (≤900 Hz) 
                    segment(1,:) = zscore(filtfilt(b,a,segment_raw)); %Bandpass envelopes 
                    segment(2,:) = zscore(BpPowerEnvelope(segment_raw, 20, 100, fs)); 
                    segment(3,:) = zscore(BpPowerEnvelope(segment_raw, 80, 250, fs)); 
                    segment(4,:) = zscore(BpPowerEnvelope(segment_raw, 200, 600, fs)); 
                    segment(5,:) = zscore(BpPowerEnvelope(segment_raw, 500, 900, fs)); 
                    img = imresize(segment, convnet.Layers(1).InputSize(1:2)); 
                    [label,~] = classify(convnet, img); 
                    switch label 
                        case 'noise'; CNN_artifacts(i,ch) = 1; 
                    end
                end 
            end
            CNN_artifacts_all = [CNN_artifacts_all;CNN_artifacts];
        end
                % remove seizures from CNN time
        sample_wise_artifacts = repelem(CNN_artifacts_all, windowSize, 1);
        seizure_mask = false(size(sample_wise_artifacts,1),1);
        for i = 1:size(seizure_samples,1)
            s = seizure_samples(i,1);
            e = seizure_samples(i,2);
            seizure_mask(s:e) = true;
        end
        sample_wise_artifacts(end+1:size(seizure_mask,1), :) = 0;
        clean_mask = ~sample_wise_artifacts & ~seizure_mask;
        clean_duration_per_channel = sum(clean_mask, 1) / fs;
    end
end