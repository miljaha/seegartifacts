function [occurance_rate, occupancy_rate] = occurance_occupancy_rate(num_channels, exclude_channel_idx, fs, sig_events, sig_duration)
%%% Updated on 3.7.2026 by Mohammad Al-Sa'd
occurance_rate = zeros(num_channels, size(sig_events,2));
occupancy_rate = zeros(num_channels, size(sig_events,2));
for i = 1:size(sig_events,2)
    if sig_duration{i} > 0
        for j = 1:num_channels % iterate through the channels
            occurance_rate(j,i) = sum(sig_events{i}(:,1) == j)/sig_duration{i};
            occupancy_rate(j,i) = (sum(sig_events{i}(sig_events{i}(:,1) == j, 4))/fs)/sig_duration{i};
        end
    else % make sure that invalid entries (duration = 0 and zero detections) are zero
        occurance_rate(j,i) = 0;
        occupancy_rate(j,i) = 0;
    end
end

% Make sure that excluded channels have nan entries
occurance_rate(exclude_channel_idx,:) = nan;
occupancy_rate(exclude_channel_idx,:) = nan;

% Convert rate to be in minutes and occupancy to percentages
occurance_rate = 60.*occurance_rate;
occupancy_rate = 100.*occupancy_rate;
end