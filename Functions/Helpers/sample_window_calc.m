function sample_window = sample_window_calc(data, user_datetime_range, fs, start_datetime)

    data = data.x_bip;
    N = size(data,2);                      % number of samples
    end_datetime = start_datetime + seconds((N-1)/fs);
    
    % Correct user range if out of bounds
    start_dt = max(user_datetime_range{1}, start_datetime);
    end_dt   = min(user_datetime_range{2}, end_datetime);
    
    % Convert datetimes to sample indices
    start_sample = floor(seconds(start_dt - start_datetime) * fs) + 1;
    end_sample   = floor(seconds(end_dt - start_datetime) * fs) + 1;
    
    % Define sample_window exactly like in your EDF code
    sample_window = [start_sample; end_sample];