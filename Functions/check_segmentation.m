function segment_sample_window = check_segmentation(edf_filename, user_segment_duration, sample_window, sampling_rate)
%% Check data segmentation for each edf file (updated on 1.7.2026 by Mohammad Al-Sa'd)
num_edf_files = size(edf_filename,1);
user_segment_duration = double(user_segment_duration);
if ~isempty(user_segment_duration)
    if isnan(user_segment_duration) || user_segment_duration <= 0 || ~isscalar(user_segment_duration) || mod(user_segment_duration,1) ~= 0
        error('The segment duration in seconds must be a positive integer!');
    else
        fprintf('The selected segment duration is %d seconds\n', user_segment_duration);
    end
else
    fprintf('Segmentation is deactivated and the full signal duration is analyzed\n');
end
segment_sample_window = cell(1,num_edf_files); % initialize a cell for the segments' start and end samples
for file_number = 1:num_edf_files % iteratre through the subject's included files/recordings
    if ~isempty(user_segment_duration) % if the segment duration is defined
        st = sample_window(1,file_number); % get the edf overall start
        fi = sample_window(2,file_number); % get the edf overall end
        I = unique([st:(user_segment_duration*sampling_rate(file_number)):fi fi]); % compute the segment starts and ends
        J = diff(I); % check the segment duration in samples
        if length(J) > 1 && J(end) < (user_segment_duration*sampling_rate(file_number)) % if we have at least 2 segments and the last segment is short
            I(end-1) = []; % combine it with previous one as one segment
        end
        segment_sample_window{file_number} = reshape([I(1) repelem(I(2:end-1), 2), I(end)], 2, length(I) - 1); % reshape the array
        fprintf("The number of segments for file ""%s"" is %d\n", edf_filename(file_number), size(segment_sample_window{file_number},2));
    else % if the segment duration is not defined (no segmentation)
        segment_sample_window{file_number} = sample_window(:,file_number); % take the full defined signal duration
    end
end
end