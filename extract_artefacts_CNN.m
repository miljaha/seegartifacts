subj_nums = [12];%,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,40,41,42,43,44,45,46,47,48,50,51,52,53,54,55,56,57,58,59,60];         % Subject number
% find files automatically, extract artefacts and bad channels, load
% artefact times only
data_files = {""};
user_datetime_range = {"",""};
user_segment_duration = [];

for i = 1:length(subj_nums)
    fprintf("Starting subject %d\n",subj_nums(i))

    data_dir = "/projects3/EPIHFO/EPIHFO/Pat" + string(subj_nums(i));
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
    end
end