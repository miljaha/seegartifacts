% Multi-Subject Utility
% % Input Parameters

% Subjects to be analysed in a loop
subj_nums = [12];%,19,20,21,22,23,24,25,26,27,28,29,30];
%,31,32,33,34,35,36,37,38,40,41,42,43,44,45,46,47,48,50,52,53,56,58,59,60];         % Subject number
% 51, 54, 55 ja 57 odottaa Päivin merkintöjä

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
startTime = "1:50"; %%%%%%%%%%
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
endTime = "2:15"; %%%%%%%%%%%%%%%%%
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

load('convnet.mat') 

% check fs
file_name = edf_filename(1);
fs = sampling_rate(1); % get the edf file sampling rate
fprintf("Sampling frequency is %d Hz\n",fs);
max_length = max_length_mins*60*fs;            % min x sec x samples
min_length = min_length_mins*60*fs;

all_noise_probs = zeros(0,0);
CNN_timepoints_probs = zeros(0,0); % total noise probability per CNN segment
CNN_timepoints_n = zeros(0,0); % sum of channels artefactual per segment
%
fprintf(2,"======       Beginning of analysis        ======\n")
% Main Script applied to each subject's record separately
for file_number = 1:num_edf_files % iteratre through the subject's included files/recordings
    % Logic flages to check if accessing a prior file is needed
    handle_file    = true;
    looped_already = false;

     FR_all = zeros(0,4);
    FR_both_removed_all = zeros(0,4);
    FR_CNN_removed_all = zeros(0,4);
    
    IED_all = zeros(0,4);
    IED_both_removed_all = zeros(0,4);
    IED_CNN_removed_all = zeros(0,4);
    
    R_all = zeros(0,4);
    R_both_removed_all = zeros(0,4);
    R_CNN_removed_all = zeros(0,4);
    
    GS_all = zeros(0,4);
    GS_both_removed_all = zeros(0,4);
    GS_CNN_removed_all = zeros(0,4);

    SFR_original_all = zeros(0,4);
    SFR_both_removed_all = zeros(0,4);
    SFR_CNN_removed_all = zeros(0,4);
        
    SRipples_original_all = zeros(0,4);
    SRipples_both_removed_all = zeros(0,4);
    SRipples_CNN_removed_all = zeros(0,4);

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
        badchans = extract_bad_channels(badchans_raw);
        bad_channel_idx = ismember(lower(bipolar_labels), badchans);
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

            windowSize = fs*3; % samples per segment 
            overlap = 0; % 
            step = windowSize - overlap; 
            numSegments = floor((size(data.x_bip,1) - windowSize) / step)+1;
            [b,a] = butter(3, 900/(0.5*fs), 'low');
            CNN_artifacts = zeros(numSegments,size(data.x_bip,2));
            noise_probs = CNN_artifacts;
         
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
                    [label,probs] = classify(convnet, img); 
                    switch label 
                        case 'noise'; CNN_artifacts(i,ch) = 1; 
                    end
                    noise_probs(i,ch) = probs(1);
                end 
            end
            all_noise_probs = [all_noise_probs; noise_probs];
            CNN_timepoints_probs = [CNN_timepoints_probs; sum(noise_probs,2)];
            CNN_timepoints_n = [CNN_timepoints_n, sum(CNN_artifacts,2)];
            %% Fast ripple detection
           
            fprintf(2,'======                           Fast ripple detection                          ======\n');
            FR_original = HFO_detector(data.x_bip, fs); % detection
            R_original = Ripple_detector(data.x_bip, fs); % detection
            FR_original(:,3) = FR_original(:,3) + sample_window_max(1,s) - 1;  % shift start time
            R_original(:,3) = R_original(:,3) + sample_window_max(1,s) - 1; % shift start time

            FR_all = [FR_all; FR_original];
            R_all = [R_all; R_original];
            fprintf('%d original HFOs were detected successfully ...\n', size(FR_original,1));
            fprintf('%d original ripples were detected successfully ...\n', size(R_original,1));
           
            %% General spikes detection
            fprintf(2,'\n======                         General spikes detection                         ======\n');
            settings = '-h 50 -dec 200 -b 8';
            Spikes = spike_detector_hilbert_v23(data.x_bip, fs, settings); % detection
            Spikes.pos = Spikes.pos(:).*fs + sample_window_max(1,s);   % start in samples (rounding is removed on purpose)
            Spikes.dur = Spikes.dur(:).*fs;   % duration in samples (rounding is removed on purpose)
            IED_original = [Spikes.chan, nan(size(Spikes.chan)), Spikes.pos, Spikes.dur]; % gather all results (similar format to FR)
            IED_all = [IED_all; IED_original];

            fprintf('%d original IEDs were detected successfully ...\n', size(IED_original,1));
           
            %% Milja: Gamma-Spikes testing
            fprintf(2,'\n======                         Gamma-spike detection                         ======\n');
            GammaSpikes = Gamma_detector_new(data.x_bip, IED_original ,fs, sample_window_max(1,s));
            GammaSpikes(:,3) = GammaSpikes(:,3) + sample_window_max(1,s);
            GS_all =  [GS_all; GammaSpikes];

            fprintf('%d original gamma-IEDs were detected successfully ...\n', size(GammaSpikes,1));
            
            %% Postprocessing
            fprintf(2,'\n======                              Postprocessing                              ======\n');
            % Remove FR segments overlapping with artefact and/or seizure segments
            FR_both_removed = exclude_samples(FR_original, both_samples, 0, 0, 'combined artefact & seizure');
            FR_both_removed_all = [FR_both_removed_all; FR_both_removed];
            FR_seizures_removed = exclude_samples(FR_original, seizure_samples , 0, 0, 'seizure');
            FR_CNN_removed = exclude_CNN(FR_seizures_removed, CNN_artifacts, sample_window_max, s,fs);
            FR_CNN_removed_all = [FR_CNN_removed_all; FR_CNN_removed];
            
            % Remove Spike segments overlapping with artefact and/or seizure segments
            IED_both_removed = exclude_samples(IED_original, both_samples, 0, 0, 'combined artefact & seizure');
            IED_both_removed_all = [IED_both_removed_all;IED_both_removed];
            IED_seizures_removed = exclude_samples(IED_original, seizure_samples , 0, 0, 'seizure');
            IED_CNN_removed = exclude_CNN(IED_seizures_removed, CNN_artifacts, sample_window_max, s,fs);
            IED_CNN_removed_all = [IED_CNN_removed_all;IED_CNN_removed];
          
            % Ripples (Milja)
            R_both_removed = exclude_samples(R_original, both_samples, 0, 0, 'combined artefact & seizure');
            R_both_removed_all = [R_both_removed_all; R_both_removed];
            R_seizures_removed = exclude_samples(R_original, seizure_samples , 0, 0, 'seizure');
            R_CNN_removed = exclude_CNN(R_seizures_removed, CNN_artifacts, sample_window_max, s,fs);
            R_CNN_removed_all = [R_CNN_removed_all; R_CNN_removed];
            
            % GammaSpikes
            GS_both_removed = exclude_samples(GammaSpikes, both_samples, 0, 0, 'combined artefact & seizure');
            GS_both_removed_all = [GS_both_removed_all; GS_both_removed];
            GS_seizures_removed = exclude_samples(GammaSpikes, seizure_samples , 0, 0, 'seizure');
            GS_CNN_removed = exclude_CNN(GS_seizures_removed, CNN_artifacts, sample_window_max, s,fs);
            GS_CNN_removed_all = [GS_CNN_removed_all; GS_CNN_removed];
            
            
            %% FR-based spikes detection
            fprintf(2,'\n======                         FR-based spikes detection                        ======\n');
            N_buffer = 0.1*fs + 1;  % 100ms buffer
            
            SFR_original = find_spikes_in_ripples(FR_original, IED_original, N_buffer);
            SFR_original_all = [SFR_original_all; SFR_original];     
            SFR_both_removed = find_spikes_in_ripples(FR_both_removed, IED_both_removed, N_buffer);
            SFR_both_removed_all = [SFR_both_removed_all; SFR_both_removed];            
            SFR_CNN_removed = find_spikes_in_ripples(FR_CNN_removed, IED_seizures_removed, N_buffer);
            SFR_CNN_removed_all = [SFR_CNN_removed_all; SFR_CNN_removed];
      
            fprintf('%d original SFRs successfully detected...\n', size(SFR_original,1));
       
            % ==== Ripple-based spikes (Milja) ====
            fprintf(2,'\n====== Ripple-based spikes detection ======\n')
            SRipples_original = find_spikes_in_ripples(R_original, IED_original, N_buffer);
            SRipples_original_all = [SRipples_original_all; SRipples_original];    
            SRipples_both_removed = find_spikes_in_ripples(R_both_removed, IED_both_removed, N_buffer);
            SRipples_both_removed_all = [SRipples_both_removed_all; SRipples_both_removed];            
            SRipples_CNN_removed = find_spikes_in_ripples(R_CNN_removed, IED_seizures_removed, N_buffer);
            SRipples_CNN_removed_all = [SRipples_CNN_removed_all; SRipples_CNN_removed];
            
            fprintf('%d original SRs successfully detected...\n', size(SRipples_original,1));

            % collect CNN artifacts to matrix, each entry represents 3
            % seconds
            CNN_artifacts_all = [CNN_artifacts_all;CNN_artifacts];
            fprintf(2,"===== Moving to next segment =====\n")
        end
        fprintf(2,"===== Segments done, calculating the rates =====\n")
        duration_artefacts = remaining_duration(sample_window, artefact_samples, duration_original, fs);
        duration_seizures  = remaining_duration(sample_window, seizure_samples, duration_original, fs);
        duration_both     = remaining_duration(sample_window, both_samples, duration_original, fs);

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
        %% Rate computations
        fprintf(2,'\n======                             Rate computations                            ======\n');
        % in minutes
        duration_original = duration_original/60;
        duration_artefacts_removed = duration_artefacts/60;
        duration_seizures_removed  = duration_seizures/60;
        duration_both_removed  = duration_both/60;
        duration_CNN_removed = clean_duration_per_channel/60;
        all_CNN_durations = [all_CNN_durations; duration_CNN_removed];
        % Calculate FR/IED/SFR rates (per second) and percentages of occupancy for each channel
        FR_appear_rate     = zeros(length(data.lab_bip), 3);
        R_occupancy_rate  = zeros(length(data.lab_bip), 3);
        R_appear_rate     = zeros(length(data.lab_bip), 3);
        FR_occupancy_rate  = zeros(length(data.lab_bip), 3);
        
        IED_appear_rate    = zeros(length(data.lab_bip), 3);
        IED_occupancy_rate = zeros(length(data.lab_bip), 3);
 
        SFR_appear_rate    = zeros(length(data.lab_bip), 3);
        SFR_occupancy_rate = zeros(length(data.lab_bip), 3);

        SRipples_appear_rate    = zeros(length(data.lab_bip), 3);
        SRipples_occupancy_rate = zeros(length(data.lab_bip), 3);

        GS_appear_rate     = zeros(length(data.lab_bip), 3);
        GS_occupancy_rate  = zeros(length(data.lab_bip), 3);

        for j = 1:length(data.lab_bip) % iterate through the channels
            FR_appear_rate(j,1)     = sum(FR_all(:,1) == j)/duration_original;
            FR_appear_rate(j,2)     = sum(FR_both_removed_all(:, 1) == j)/duration_both_removed;
            FR_appear_rate(j,3)     = sum(FR_CNN_removed_all(:,1) ==j)/ duration_CNN_removed(j);
            FR_occupancy_rate(j,1)  = (sum(FR_all(FR_all(:,1) == j, 4))/fs)/duration_original;
            FR_occupancy_rate(j,2)  = (sum(FR_both_removed_all(FR_both_removed_all(:,1) == j, 4))/fs)/duration_both_removed;
            FR_occupancy_rate(j,3)  = (sum(FR_CNN_removed_all(FR_CNN_removed_all(:,1) == j, 4))/fs)/duration_CNN_removed(j);

            R_appear_rate(j,1)     = sum(R_all(:,1) == j)/duration_original;
            R_appear_rate(j,2)     = sum(R_both_removed_all(:, 1) == j)/duration_both_removed;
            R_appear_rate(j,3)     = sum(R_CNN_removed_all(:,1) == j)/duration_CNN_removed(j);
            R_occupancy_rate(j,1)  = (sum(R_all(R_all(:,1) == j, 4))/fs)/duration_original;
            R_occupancy_rate(j,2)  = (sum(R_both_removed_all(R_both_removed_all(:,1) == j, 4))/fs)/duration_both_removed;
            R_occupancy_rate(j,3)  = (sum(R_CNN_removed_all(R_CNN_removed_all(:,1) == j, 4))/fs)/duration_CNN_removed(j);

            % original IED
            IED_appear_rate(j,1)    = sum(IED_all(:,1) == j)/duration_original; 
            IED_appear_rate(j,2)    = sum(IED_both_removed_all(:, 1) == j)/duration_both_removed;
            IED_appear_rate(j,3)    = sum(IED_CNN_removed_all(:,1) == j)/duration_CNN_removed(j);
            IED_occupancy_rate(j,1) = (sum(IED_all(IED_all(:,1) == j, 4))/fs)/duration_original;
            IED_occupancy_rate(j,2) = (sum(IED_both_removed_all(IED_both_removed_all(:,1) == j, 4))/fs)/duration_both_removed;
            IED_occupancy_rate(j,3) = (sum(IED_CNN_removed_all(IED_CNN_removed_all(:,1) == j, 4))/fs)/duration_CNN_removed(j);

            % Spike Fast Ripples
            SFR_appear_rate(j,1)    = sum(SFR_original_all(:,1) == j)/duration_original;
            SFR_appear_rate(j,2)    = sum(SFR_both_removed_all(:, 1) == j)/duration_both_removed;
            SFR_appear_rate(j,3)    = sum(SFR_CNN_removed_all(:,1) == j)/duration_CNN_removed(j);
            SFR_occupancy_rate(j,1) = (sum(SFR_original_all(SFR_original_all(:,1) == j, 4))/fs)/duration_original;
            SFR_occupancy_rate(j,2) = (sum(SFR_both_removed_all(SFR_both_removed_all(:,1) == j, 4))/fs)/duration_both_removed;
            SFR_occupancy_rate(j,3) = (sum(SFR_CNN_removed_all(SFR_CNN_removed_all(:,1) == j, 4))/fs)/duration_CNN_removed(j);

            % Spike-ripples, Milja
            SRipples_appear_rate(j,1)    = sum(SRipples_original_all(:,1) == j)/duration_original;
            SRipples_appear_rate(j,2)    = sum(SRipples_both_removed_all(:, 1) == j)/duration_both_removed;
            SRipples_appear_rate(j,3)    = sum(SRipples_CNN_removed_all(:,1) == j)/duration_CNN_removed(j);
            SRipples_occupancy_rate(j,1) = (sum(SRipples_original_all(SRipples_original_all(:,1) == j, 4))/fs)/duration_original;
            SRipples_occupancy_rate(j,2) = (sum(SRipples_both_removed_all(SRipples_both_removed_all(:,1) == j, 4))/fs)/duration_both_removed;
            SRipples_occupancy_rate(j,3) = (sum(SRipples_CNN_removed_all(SRipples_CNN_removed_all(:,1) == j, 4))/fs)/duration_CNN_removed(j);

            % Gamma-spikes, Milja
            GS_appear_rate(j,1)    = sum(GS_all(:,1) == j)/duration_original;
            GS_appear_rate(j,2)    = sum(GS_both_removed_all(:, 1) == j)/duration_both_removed;
            GS_appear_rate(j,3)    = sum(GS_CNN_removed_all(:,1) == j)/duration_CNN_removed(j);
            GS_occupancy_rate(j,1) = (sum(GS_all(GS_all(:,1) == j, 4))/fs)/duration_original;
            GS_occupancy_rate(j,2) = (sum(GS_both_removed_all(GS_both_removed_all(:,1) == j, 4))/fs)/duration_both_removed;
            GS_occupancy_rate(j,3) = (sum(GS_CNN_removed_all(GS_CNN_removed_all(:,1) == j, 4))/fs)/duration_CNN_removed(j);

        end
        % Make sure that nan entries (duration = 0) are zero
        FR_appear_rate(isnan(FR_appear_rate)) = 0;
        R_appear_rate(isnan(FR_appear_rate)) = 0;
        IED_appear_rate(isnan(IED_appear_rate)) = 0;
        SFR_appear_rate(isnan(SFR_appear_rate)) = 0;
        SRipples_appear_rate(isnan(SRipples_appear_rate)) = 0;
        GS_appear_rate(isnan(GS_appear_rate)) = 0;

        FR_occupancy_rate(isnan(FR_occupancy_rate)) = 0;
        R_occupancy_rate(isnan(FR_occupancy_rate)) = 0;
        IED_occupancy_rate(isnan(IED_occupancy_rate)) = 0;
        SFR_occupancy_rate(isnan(SFR_occupancy_rate)) = 0;
        SRipples_occupancy_rate(isnan(SRipples_occupancy_rate)) = 0;
        GS_occupancy_rate(isnan(GS_occupancy_rate)) = 0;

        disp("Total duration in minutes without anything removed: " + string(duration_original));
        disp("Total duration in minutes with both artefacts and seizures removed: " + string(duration_both_removed));

        % Convert occupancy to percentages
        FR_occupancy_rate  = 60.*FR_occupancy_rate;
        R_occupancy_rate = 60.*R_occupancy_rate;
        IED_occupancy_rate = 60.*IED_occupancy_rate;
        SFR_occupancy_rate = 60.*SFR_occupancy_rate;
        SRipples_occupancy_rate = 60.*SRipples_occupancy_rate;
        GS_occupancy_rate = 60.*GS_occupancy_rate;


        %% Mark bad channels by annotations as NaN for columns 1-4
        %{
        FR_appear_rate(bad_channel_idx,1:4) = NaN;
        R_appear_rate(bad_channel_idx,1:4) = NaN;
        IED_appear_rate(bad_channel_idx,1:4) = NaN;
        SFR_appear_rate(bad_channel_idx,1:4) = NaN;
        SRipples_appear_rate(bad_channel_idx,1:4) = NaN;
        GS_appear_rate (bad_channel_idx,1:4) = NaN;

        FR_occupancy_rate(bad_channel_idx,1:4) = NaN;
        R_occupancy_rate(bad_channel_idx,1:4) = NaN;
        IED_occupancy_rate(bad_channel_idx,1:4) = NaN;
        SFR_occupancy_rate(bad_channel_idx,1:4) = NaN;
        SRipples_occupancy_rate(bad_channel_idx,1:4) = NaN;
        GS_occupancy_rate(bad_channel_idx,1:4) = NaN;
        %}
        %% Save subject's raw detections in MAT file
        fprintf(2,'\n======               Save detections for file "%s"              ======\n', file_name);
        matfile = fullfile(data_dir, string(erase(file_name, ".edf")) + "_detections");
        FR_detections.original = FR_original;
        FR_detections.both_removed = FR_both_removed;
        
        R_detections.original = R_original;
        R_detections.both_removed = R_both_removed;
        
        IED_detections.original = IED_original;
        IED_detections.both_removed = IED_both_removed;

        SFR_detections.original = SFR_original;
        SFR_detections.both_removed = SFR_both_removed;

        SRipples_detections.original = SRipples_original;
        SRipples_detections.both_removed = SRipples_both_removed;

        GS_detections.original = GammaSpikes;
        GS_detections.both_removed = GS_both_removed;
   

        Duration_min.original = duration_original;
        Duration_min.artefacts_removed = duration_artefacts_removed;
        Duration_min.seizures_removed = duration_seizures_removed;
        Duration_min.both_removed = duration_both_removed;
        sampling_rate = fs;
        detections_format = {"channel number","frequency or nan","start sample","duration in samples"};
        notes = "The IED start and sample durations are not rounded. This affects also the SFR detections";
        save(matfile,'FR_detections','R_detections','IED_detections','SFR_detections','SRipples_detections',"GS_detections",'Duration_min', ...
            'sampling_rate','detections_format','notes');
        fprintf('File "%s" is saved successfully ...\n', string(erase(file_name, ".edf")) + "_detections" + ".mat");

        %% Export summary results to an Excel file
        fprintf(2,'\n======                Export rates for file "%s"                ======\n', file_name);
        excelfile = fullfile(data_dir, "detection_rates_pat" + subj_num + ".xls");
        % if idx == 1 && exist(excelfile,'file') > 0, delete(excelfile); end % check if an older excel file exists and delete it
        sheet_name = string(erase(file_name, ".edf"));
        % Write the file/signal information
        info{1,1} = file_name;
        info{2,1} = string(start_datetime(idx));
        info{3,1} = string(end_datetime(idx));
        info{4,1} = duration_original;
        info{5,1} = duration_both_removed;
        info{6,1} = mean(duration_CNN_removed);
        writecell({'File:';'Time start:';'Time end:';'Original duration (min):'; ...
            'Duration with manual artefacts removed (min):';'Average duration with CNN artefacts removed (min):'},excelfile,'Sheet',sheet_name,'Range','A1');
        writecell(info,excelfile,'Sheet',sheet_name,'Range','B1');
        % Write the channel numbers and labels
        writematrix((1:length(data.lab_bip))',excelfile,'Sheet',sheet_name,'Range','A11');
        writematrix(data.lab_bip,excelfile,'Sheet',sheet_name,'Range','B11');
        writematrix(double(bad_channel_idx), excelfile,'Sheet',sheet_name,'Range','C11')
        writematrix(duration_CNN_removed', excelfile,'Sheet',sheet_name,'Range','D11')
        % Write column headers
        main_hdr = {
            'FR rate (1/min)', '', '';
            'R rate (1/min)', '', '';
            'IED rate (1/min)', '', '';
            'SFR rate (1/min)', '', '';
            'SRipple rate (1/min)', '', '';
            'GS rate (1/min)', '', '';

            'FR occupancy (%)', '', '';
            'R occupancy (%)', '', '';
            'IED occupancy (%)', '', '';
            'SFR occupancy (%)', '', '';
            'SRipple occupancy (%)', '', '';
            'GS occupancy (%)', '', '';
            };
        sub_block = {'Original','Manual','CNN'};
        sub_hdr = [{'Channel number','Label','Bad channel', 'Duration after CNN'} repmat(sub_block, 1, 12)];

        writecell(reshape(main_hdr',1,[]),excelfile,'Sheet',sheet_name,'Range','E9');
        writecell(sub_hdr,excelfile,'Sheet',sheet_name,'Range','A10');
        % Write the rates and percentages of occupancy
        writematrix(FR_appear_rate,        excelfile,'Sheet',sheet_name,'Range','E11');
        writematrix(R_appear_rate,         excelfile,'Sheet',sheet_name,'Range','H11');
        writematrix(IED_appear_rate,       excelfile,'Sheet',sheet_name,'Range','K11');
        writematrix(SFR_appear_rate,       excelfile,'Sheet',sheet_name,'Range','N11');
        writematrix(SRipples_appear_rate,  excelfile,'Sheet',sheet_name,'Range','Q11');
        writematrix(GS_appear_rate,        excelfile,'Sheet',sheet_name,'Range','T11');
        
        writematrix(FR_occupancy_rate,        excelfile,'Sheet',sheet_name,'Range','W11');
        writematrix(R_occupancy_rate,         excelfile,'Sheet',sheet_name,'Range','Z11');
        writematrix(IED_occupancy_rate,       excelfile,'Sheet',sheet_name,'Range','AC11');
        writematrix(SFR_occupancy_rate,       excelfile,'Sheet',sheet_name,'Range','AF11');
        writematrix(SRipples_occupancy_rate,  excelfile,'Sheet',sheet_name,'Range','AI11');
        writematrix(GS_occupancy_rate,        excelfile,'Sheet',sheet_name,'Range','AL11');

        %% Gather file information from the subject's records
        % Save necessary information for combined file statistics
        all_labels{idx} = data.lab_bip;
        all_info{idx}   = info';
        all_rates{idx}  = [FR_appear_rate,...
            R_appear_rate, ...
            IED_appear_rate, ...
            SFR_appear_rate,...
            SRipples_appear_rate, ...
            GS_appear_rate, ...
            FR_occupancy_rate, ...
            R_occupancy_rate,...
            IED_occupancy_rate,...
            SFR_occupancy_rate, ...
            SRipples_occupancy_rate, ...
            GS_occupancy_rate];

        %% Check if need to redo previous file
        handle_file = false;
        if seizure_time_overflow_start > 0 && ~looped_already && idx > 1
            handle_file = true;
            looped_already = true;
            disp([newline '--- Seizure time overflows to previous file, reaccessing it ---' newline]);
        end
        clear data;
    end
end

% Weighted mean of the subject's records (continue only with common channels)
% Find common labels across all files
common_labels = all_labels{1};
for i = 2:length(all_labels)
    common_labels = intersect(common_labels, all_labels{i}, 'stable');
end
% Keep rates with labels in common_labels and compute total rates and durations
common_values = zeros(length(common_labels),size(all_rates{1},2));
all_durations = 0;
for i = 1:length(all_labels)
    [~, label_idx]  = ismember(common_labels, all_labels{i});
    durations_bloc = [repmat(cell2mat(all_info{i}(4:5)),length(common_labels),1),all_CNN_durations(i,:)'];
    dur_matrix = repmat(durations_bloc, 1, 12);
    temp = all_rates{i}(label_idx,:).*dur_matrix;
    common_values = common_values + temp;
    all_durations = all_durations + dur_matrix(1,:);
end
common_values = common_values./all_durations;

% Export the combined results to a separate Excel sheet
fprintf(2,'\n======           Export combined rates for file "%s"            ======\n', file_name);
excelfile = fullfile(data_dir, "detection_rates_pat" + subj_num + ".xls");
sheet_name = "files combined";
% Write the subject information
all_start_times = cellfun(@(x) x{2}, all_info);
all_end_times   = cellfun(@(x) x{3}, all_info);
mf_info{1,1} = "Multiple files";
mf_info{2,1} = string(min(datetime(all_start_times,'Format',datetime_format)));
mf_info{3,1} = string(max(datetime(all_end_times,'Format',datetime_format)));
mf_info{4,1} = all_durations(1);
mf_info{5,1} = all_durations(2);
mf_info{6,1} = all_durations(3);
mf_info{7,1} = all_durations(4);
writecell({'File:';'Time start:';'Time end:';'Original duration (min):'; ...
            'Duration with manual artefacts removed (min):';'Average duration with CNN artefacts removed (min):'},excelfile,'Sheet',sheet_name,'Range','A1');
writecell(mf_info,excelfile,'Sheet',sheet_name,'Range','B1');
% Write the common channel numbers and labels
writematrix((1:length(common_labels))',excelfile,'Sheet',sheet_name,'Range','A11');
writematrix(common_labels,excelfile,'Sheet',sheet_name,'Range','B11');
% Write column headers
main_hdr = {
            'FR rate (1/min)', '', '';
            'R rate (1/min)', '', '';
            'IED rate (1/min)', '', '';
            'SFR rate (1/min)', '', '';
            'SRipple rate (1/min)', '', '';
            'GS rate (1/min)', '', '';

            'FR occupancy (%)', '', '';
            'R occupancy (%)', '', '';
            'IED occupancy (%)', '', '';
            'SFR occupancy (%)', '', '';
            'SRipple occupancy (%)', '', '';
            'GS occupancy (%)', '', '';
            };
sub_block = {'Original','Manual','CNN'};
sub_hdr = [{'Channel number','Label','Bad channel', 'Duration after CNN','Total noise (p/d)'} repmat(sub_block, 1, 12)];

writecell(reshape(main_hdr',1,[]),excelfile,'Sheet',sheet_name,'Range','F9');
writecell(sub_hdr,excelfile,'Sheet',sheet_name,'Range','A10');
writematrix(double(bad_channel_idx), excelfile,'Sheet',sheet_name,'Range','C11')
writematrix(sum(all_CNN_durations,1)', excelfile,'Sheet',sheet_name,'Range','D11')

total_noise = sum(all_noise_probs,1) ./ all_durations(1);
writematrix(total_noise, excelfile,'Sheet',sheet_name,'Range','E11')

% Write the combined FR/IED/SFR rates and percentages of occupancy
writematrix(common_values,excelfile,'Sheet',sheet_name,'Range','F11');
fprintf('Sheet "%s" in File "%s" is saved successfully ...\n\n', sheet_name, "detection_rates_pat" + subj_num + ".xls");

excelfile = fullfile(data_dir, "noise_times_CNN_pat" + subj_num + ".xls");
writematrix(CNN_timepoints,excelfile,'Range','A1');

out = "The program has finished";
end