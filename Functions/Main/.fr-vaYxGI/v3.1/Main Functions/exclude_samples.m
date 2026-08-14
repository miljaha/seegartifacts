function [event_samples_removed] = exclude_samples(events, samples, loop_index, block_size)
% MA: The function is vectorized and requires no for loops
% Removes events that overlap with given sample intervals
% Handles event shifting and interval comparison


% Early exit if no samples to remove
if isempty(samples)
    event_samples_removed = events;
    return;
end

% Compute global intervals
event_start = events(:,3) + (loop_index - 1) * block_size;
event_end   = event_start + events(:,4);

% Vectorized overlap check
s_start = samples(:,1)';
s_end   = samples(:,2)';

overlap_matrix = (event_start <= s_end) & (event_end >= s_start);  % NxM
reject = any(overlap_matrix, 2);  % N x 1

% Remove overlapping ripples
event_samples_removed = events(~reject, :);

end