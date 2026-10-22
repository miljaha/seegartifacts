function data = read_and_classify_data(subj_num, data_dir)
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
    handle_file    = true;
    looped_already = false;
    while handle_file
        %% Checking data and annotations from the edf file
        idx = file_number - 1.*looped_already; % determine the index of the file to be handled
        file_name = edf_filename(idx);  % get the edf filename
        fprintf(2,'======        Checking data and annotations in file "%s"        ======\n', file_name);
        [fs, N, label, events] = check_data(data_dir, file_name);

        %% Extracting bad channels from the edf file
        fprintf(2,'\n======           Extracting bad channels in file "%s"           ======\n', file_name);
        [~, bipo_inds, ~] = bipolar_montage_indices(label); % get montage indices
        bipolar_labels = lower(string([char(label{bipo_inds(:,1)}) ...
            repelem('-',length(bipo_inds),1) char(label{bipo_inds(:,2)})]));   % convert unipolar labels to bipolar
        bipolar_labels = erase(bipolar_labels,' ');                            % remove any empty spaces if exists
        ch_idx = 1:size(bipolar_labels,1);                                     % initialize the channel array

        

        %% Extracting artefact and seizure segments from annotations
        fprintf(2,'\n======         Extracting artefact and seizure segments from annotations        ======\n');
        artefact_samples = extract_artefact_locations(events, N, fs); % search for the artefact samples in the file
        % search for seziure samples in the file and gather buffered seizure timestamps from events
        [seizure_samples, overflow_start, overflow_end] = extract_seizure_locations(events, N, fs, ...
            seizure_time_overflow_start, seizure_time_overflow_end, looped_already);
        % combine artefact and seizure intervals
        both_samples = merge_intervals(seizure_samples, artefact_samples);
        % save seizure time overflows (overflows at start -> Goes to PREVIOUS file)
        seizure_time_overflow_start = overflow_start;
        % Only saves the end overflow if not rehandling prior file (overflows at end -> Goes to NEXT file)
        if ~looped_already, seizure_time_overflow_end = overflow_end; end

        %% Applying the automatic detection pipeline
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
        end
    end
end
