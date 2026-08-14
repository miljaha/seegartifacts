function [edf_filename, start_datetime, end_datetime, sampling_rate, sample_window, num_edf_files] = exclude_files(edf_filename, user_datetime_range, start_datetime, end_datetime, data_length, sampling_rate)
cond1 = end_datetime < user_datetime_range{1};   % edf files with end datetime less than the user-defined start datetime
cond2 = start_datetime > user_datetime_range{2}; % edf files with start datetime more than the user-defined end datetime
cond  = cond1 | cond2;       % combined exclusion rule
edf_filename(cond)    = [];  % exclude unnecessary filenames
start_datetime(cond)  = [];  % exclude unnecessary start datetime
end_datetime(cond)    = [];  % exclude unnecessary end datetime
data_length(cond)     = [];  % exclude unnecessary number of samples
sampling_rate(cond)   = [];  % exclude unnecessary sampling rates
% Process the start and end times of the included edf files
sample_window         = [ones(1,length(data_length)); data_length];           % the window of selected samples for each edf file
shift_in_start_time   = seconds(user_datetime_range{1} - start_datetime(1));  % shift in the start datetime
shift_in_end_time     = seconds(end_datetime(end) - user_datetime_range{2});  % shift in the end datetime
sample_window(1,1)    = floor(shift_in_start_time*sampling_rate(1) + 1);      % correct the first included edf start sample
sample_window(2,end)  = sample_window(2,end) - floor(shift_in_end_time*sampling_rate(end) + 1) + 1;  % correct the last included edf end sample
start_datetime(1)     = max(start_datetime(1),user_datetime_range{1});   % correct the first included edf start datetime
end_datetime(end)     = min(end_datetime(end),user_datetime_range{2});   % correct the last included edf end datetime
num_edf_files         = size(edf_filename,1);                            % number of included edf files
disp(table(edf_filename,string(datetime(start_datetime,"Format","dd-MM-yyyy HH:mm:ss")), ...
    string(datetime(end_datetime,"Format","dd-MM-yyyy HH:mm:ss.SSS")), ...
    'VariableNames',{'Filename','Start date/time','End date/time'})); % display meta info
start_datetime.Format = 'dd-MMMM-yyyy HH:mm:ss.SSSSSSSSS';
end_datetime.Format   = 'dd-MMMM-yyyy HH:mm:ss.SSSSSSSSS';
end