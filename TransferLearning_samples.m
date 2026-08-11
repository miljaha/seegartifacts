% full night cnn artifacts for one subject
subj_num = 22; %22 done % subject number
load('convnet.mat') 
% done
% 12,19,20,21,22,23,24,25,26,27,28,2
% undone
% ,31,32,33,34,35,36,37,38,40,41,42,43,44,45,46,47,48,50,51,52,53,54,55,56,57,58,59,60

% try
fprintf(2,"\n------ Starting subject %d ------\n\n",subj_num)
data_files = {"EEG_271-export.edf"}; % if empty it evokes automatic data file selection

data_dir = "/projects3/EPIHFO/EPIHFO/Pat" + string(subj_num);

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
T = readtable("EPIHFO_start_end_times_badChannels_Milja_vs2.xlsx");
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

%
fprintf(2,"======       Beginning of analysis        ======\n")
% Main Script applied to each subject's record separately
for file_number = 1:num_edf_files % iteratre through the subject's included files/recordings
    fprintf("\n -------- Beginning file %d / %d now --------\n", file_number,num_edf_files)
    % Loading and data extraction from EDF file
    idx = file_number;
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

    %Data preprocessing
    fprintf(2,'\n======                            Data preprocessing                            ======\n');
   
    data = uni2bi_montage(data', label); % Convert the data to the bipolar montage (MA updated)
    data_original = data.x_bip';
    
    %% Manually marked artefacts & seizures
    artefact_samples = extract_artefact_locations(events, N, fs); % Search for the artefact samples in the file (MA updated)

    fprintf("Length of data: %.2f min\n", (size(data_original,1))/fs/60);
    %% Use CNN to find alternative artefacts
    fprintf(2,"=====    Classify segments using CNN    ======\n")

    new_fs = 5000;
    windowSize = new_fs*3; % samples per segment 
    overlap = 0; % 
    step = windowSize - overlap; 
    numSegments = floor((size(data_original,1) - 3*fs) / (3*fs))+1;
    [b,a] = butter(3, 900/(0.5*new_fs), 'low');
    noise_probs = zeros(size(data_original,2),numSegments,3);
  
    for ch = 1:size(data_original, 2) % loop through channels (158) 
        broad = filtfilt(b,a,resample(data_original(:,ch),new_fs,fs));
        beta = BpPowerEnvelope(resample(data_original(:,ch),new_fs,fs), 20, 100, new_fs);
        gamma = BpPowerEnvelope(resample(data_original(:,ch),new_fs,fs), 80, 250, new_fs);
        high = BpPowerEnvelope(resample(data_original(:,ch),new_fs,fs), 200, 600, new_fs);
        ultrahigh = BpPowerEnvelope(resample(data_original(:,ch),new_fs,fs), 500, 900, new_fs);
        for i = 1:numSegments 
            startIdx = (i-1)*step + 1; 
            endIdx = startIdx + windowSize - 1;

            segment(1,:) = zscore(broad(startIdx:endIdx)); %Bandpass envelopes 
            segment(2,:) = zscore(beta(startIdx:endIdx)); 
            segment(3,:) = zscore(gamma(startIdx:endIdx)); 
            segment(4,:) = zscore(high(startIdx:endIdx)); 
            segment(5,:) = zscore(ultrahigh(startIdx:endIdx)); 
          
            probs = predict(convnet, segment); 
            noise_probs(ch,i,1) = probs(1);
            noise_probs(ch,i,2) = probs(2);
            noise_probs(ch,i,3) = probs(3);
        end 
    end

end
 
% get the bad channels
filename = "/projects3/EPIHFO/EPIHFO/Pat" + string(subj_num) + "/detection_rates_pat"+string(subj_num)+".xls";
badchannels = table2array(readtable(filename,"Sheet", "files combined", "Range","C11:C200",'VariableNamingRule','preserve'));
badchannels = badchannels(~isnan(badchannels));

%
badchannel_matrix = repmat(badchannels,1,numSegments);
artefacts_seg = artefact_samples / (3*fs);
artefact_matrix = zeros(size(noise_probs(:,:,1)));
for i = 1:size(artefacts_seg ,1)
    s = max(1,floor(artefacts_seg(i,1)));
    e = max(1,floor(artefacts_seg(i,2)));
    artefact_matrix(:,s:e) = 1;
end
badchannel_artefacts = double(artefact_matrix & badchannel_matrix);
TP_segments = badchannel_artefacts & (noise_probs(:,:,1) > 0.8);
[ch,t] = find(TP_segments==1);
locations_TP = [ch,t];
not_artefacts = badchannel_artefacts == 0;
TN_segments = not_artefacts & (noise_probs(:,:,1) > 0.5);
[ch,t] = find(TN_segments==1);
locations_TN = [ch,t];

%%
save("samples", "locations_TP","locations_TN","data_original","-v7.3")
%% ---- Precompute envelopes once per unique channel ----
uniqueChannels = unique([locations_TP(:,1); locations_TN(:,1)]);
envelopeCache = containers.Map('KeyType','double','ValueType','any');

fs = 2048;
new_fs = 5000;
windowSize = new_fs*3; % samples per segment 
overlap = 0; % 
step = windowSize - overlap; 
numSegments = floor((size(data_original,1) - 3*fs) / (3*fs))+1;
[b,a] = butter(3, 900/(0.5*new_fs), 'low');


% ---- TP segments: just slice from cache ----
fprintf("---- Extracting TP segments ---- \n")
segment_TP = zeros(5, 15000, size(locations_TP,1));
for x = 1:size(locations_TP, 1)
    ch = locations_TP(x,1);
    signal = data_original(:,ch);
    resampled = resample(signal, new_fs, fs);  

    broad = filtfilt(b, a, resampled);
    beta = BpPowerEnvelope(resampled, 20, 100, new_fs);
    gamma = BpPowerEnvelope(resampled, 80, 250, new_fs);
    high = BpPowerEnvelope(resampled, 200, 600, new_fs);
    ultrahigh = BpPowerEnvelope(resampled, 500, 900, new_fs);

    s = locations_TP(x,2) * windowSize;               % <-- fixed: was locations_TN
    e = (locations_TP(x,2)+1)*windowSize-1;
    if e > size(gamma,1)
        continue
    end
    segment_TP(1,:,x) = zscore(broad(s:e))';
    segment_TP(2,:,x) = zscore(beta(s:e))';
    segment_TP(3,:,x) = zscore(gamma(s:e))';
    segment_TP(4,:,x) = zscore(high(s:e))';
    segment_TP(5,:,x) = zscore(ultrahigh(s:e))';
end
fprintf("---- TP segments extracted! ---- \n\n")
%%
fprintf("---- Extracting TN segments ---- \n")
n_TN = min(size(locations_TN,1),4*size(locations_TP,1));
idx = randperm(size(locations_TN,1), n_TN);
locations_TN_selected = locations_TN(idx,:);

% ---- TN segments: same idea ----
segment_TN = zeros(5, 15000, size(locations_TN_selected,1));
for x = 1:size(locations_TN_selected, 1)
    ch = locations_TN_selected(x,1);
    signal = data_original(:,ch);
    resampled = resample(signal, new_fs, fs);  

    broad = filtfilt(b, a, resampled);
    beta = BpPowerEnvelope(resampled, 20, 100, new_fs);
    gamma = BpPowerEnvelope(resampled, 80, 250, new_fs);
    high = BpPowerEnvelope(resampled, 200, 600, new_fs);
    ultrahigh = BpPowerEnvelope(resampled, 500, 900, new_fs);

    s = locations_TN_selected(x,2) * windowSize;               % <-- fixed: was locations_TN
    e = (locations_TN_selected(x,2)+1)*windowSize-1;
    if e > size(gamma,1)
        continue
    end
    segment_TN(1,:,x) = zscore(broad(s:e))';
    segment_TN(2,:,x) = zscore(beta(s:e))';
    segment_TN(3,:,x) = zscore(gamma(s:e))';
    segment_TN(4,:,x) = zscore(high(s:e))';
    segment_TN(5,:,x) = zscore(ultrahigh(s:e))';
end

fprintf("---- TN segments extracted! ---- \n\n")
