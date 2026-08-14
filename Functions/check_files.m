function [data_length, sampling_rate, start_datetime, end_datetime, user_datetime_range, edf_filename] = check_files(data_dir, edf_filename, user_datetime_range)
num_edf_files  = size(edf_filename,1);   % number of available edf files in the subject's directory
data_length    = zeros(1,num_edf_files); % number of data samples in each edf file
sampling_rate  = zeros(1,num_edf_files); % sampling rate in each edf file
start_datetime = [];                     % variable to gather edf start datetime
end_datetime   = [];                     % variable to gather edf end datetime
for file_number = 1:num_edf_files        % iteratre through the subject's available edf files
    EDFhdr = MemReadEDF(fullfile(data_dir, edf_filename(file_number)));     % load the edf info to perform initial calculations
    data_length(file_number) = EDFhdr.NumSamples(1)*EDFhdr.NumRecords;      % number of data samples
    sampling_rate(file_number) = EDFhdr.SamplingRate(1);                    % sampling rate
    end_time = (data_length(file_number) - 1) / sampling_rate(file_number); % duration of the edf file
    dt_str = strrep(EDFhdr.StartDate,".","-") + " " + strrep(EDFhdr.StartTime,".",":") + ".0"; % start datetime of the edf file in string format
    start_datetime = cat(1,start_datetime,datetime(dt_str,"InputFormat",'dd-MM-yy HH:mm:ss.S','Format','dd-MMMM-yyyy HH:mm:ss.SSSSSSSSS')); % start datetime of the edf file
    end_datetime   = cat(1,end_datetime,start_datetime(file_number,:) + seconds(end_time)); % end datetime of the edf file
end
[start_datetime, file_cond] = sort(start_datetime); % sort the edf files according to their start datetime
edf_filename  = edf_filename(file_cond);            % rearrange the edf filenames
end_datetime  = end_datetime(file_cond);            % rearrange the edf end datetimes
data_length   = data_length(file_cond);             % rearrange the edf number of samples
sampling_rate = sampling_rate(file_cond);           % rearrange the edf sampling rates

disp(table(edf_filename,string(string(datetime(start_datetime,"Format","dd-MM-yyyy HH:mm:ss"))), ...
    string(string(datetime(end_datetime,"Format","dd-MM-yyyy HH:mm:ss.SSS"))), ...
    'VariableNames',{'Filename','Start date/time','End date/time'})); % display meta info
if isnat(user_datetime_range{1}) || user_datetime_range{1} < start_datetime(1)
    user_datetime_range{1} = start_datetime(1);
    fprintf('The start datetime is set at the earliest available ---\n');
end
if isnat(user_datetime_range{2}) || user_datetime_range{2} > end_datetime(end)
    user_datetime_range{2} = end_datetime(end);
    fprintf('The end datetime is set at the latest available ---\n');
end

end