subj_nums = [12,19,20,21,22,23,24,25,26,27,28,29,30,31,...
32,33,34,35,36,37,38,40,41,42,43,44,45,46,47,48];%,50,52,53,56,58,59,60];         % Subject numbers


for i = 1:nSubjects
    % load data
    try
        filename = "/projects3/EPIHFO/EPIHFO/Pat" + string(subj_nums(i)) + "/noise_times_CNN_pat"+string(subj_nums(i))+".xls";
        T = readtable(filename);
        n_timepoints = T{:,1}; % first col
        probs = T{:,2}; % 2nd col
        
        filename = "/projects3/EPIHFO/EPIHFO/Pat" + string(subj_nums(i)) + "/detection_rates_pat"+string(subj_nums(i))+".xls";
        badchannels = readtable(filename,"Sheet", "files combined", "Range","C11:C200",'VariableNamingRule','preserve');
        badchannels = badchannels(~isnan(table2array(T.badchannels)),1);



    catch ME
        fprintf("Problem in reading data from subject %d, skipping this subject\n", subj_nums(i))
    end
end

function [artefacts, both] = get_artefact_samples()

fprintf(2,'\n======                    Checking data and file directories                    ======\n');
if exist(data_dir,"file") > 0  % check if the data directory exists
    F = dir(fullfile(data_dir, "*.edf"));    % list all edf files in the subject's directory
    edf_filename = string({F.name}');        % gather all edf filenames
    if isempty(edf_filename) % check if there is any EDF files in the directory
        error('There are no EDF files in the selected directory!');
    else
        data_files = string(data_files);
        if ~(length(data_files) == 1 && strcmp(data_files(1),"")) % check if data file selection is auto or manual
            temp = intersect(data_files,edf_filename); % get subset of edf filenames
            if isempty(temp) % check if the selected files exist
                error('The selected EDF files do not exist in the selected directory!');
            end
        end
    end
else
   error('Data directory does not exist!');
end

% Define the datetime range as {sleep start, sleep start + 1h}
T = readtable("EPIHFO_start_end_times_badChannels_Milja.xlsx");
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

% Main Script applied to each subject's record separately
for file_number = 1:num_edf_files % iteratre through the subject's included files/recordings
    % Logic flages to check if accessing a prior file is needed
    handle_file    = true;
    looped_already = false;

    while handle_file
        %% Loading and data extraction from EDF file
        idx = file_number - 1.*looped_already; % Determine the index of the file to be handled
        file_name = edf_filename(idx);
        [EDFhdr, data] = MemReadEDF(fullfile(data_dir, file_name), 'annotations'); % load data and annotations
        fs = EDFhdr.SamplingRate(1); % get the edf file sampling rate
        [N, ~] = size(data);         % number of samples and channels
        clear data
        events = EDFhdr.Annotations;   % get the annotations
        if any(isnan([events.sample])) % check for invalid markers (MA updated)
            warning("Some annotation markers are invalid!");
            events(isnan([events.sample])) = []; % remove invalid annotations (MA updated)
            disp('Removing invalid annotations is complete!');
        end

        % Manually marked artefacts & seizures
        artefact_samples = extract_artefact_locations(events, N, fs); % Search for the artefact samples in the file (MA updated)
        % Search for seziure samples in the file and gather buffered seizure timestamps from events
        [seizure_samples, overflow_start, overflow_end] = extract_seizure_locations(events, N, fs, ...
            seizure_time_overflow_start, seizure_time_overflow_end, ...
            looped_already, sample_window(1,idx), sample_window(2,idx));
        % combine artefact and seizure intervals
        both_samples = merge_intervals(seizure_samples, artefact_samples);

        

        handle_file = false;
        if seizure_time_overflow_start > 0 && ~looped_already && idx > 1
            handle_file = true;
            looped_already = true;
            disp([newline '--- Seizure time overflows to previous file, reaccessing it ---' newline]);
        end

    end
end