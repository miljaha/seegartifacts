function [FR_samples_removed] = exclude_samples(Fast_Ripples, samples, loop_index, block_size, sample_type)
% MA: The function is vectorized and requires no for loops
% Removes Fast Ripples that overlap with given sample intervals
% Handles ripple shifting and interval comparison

disp(['--- Perform ' sample_type ' rejection based on manual annotations ---']);

% Early exit if no samples to remove
if isempty(samples)
    FR_samples_removed = Fast_Ripples;
    disp(['--- No ' sample_type ' samples to remove ---']);
    return;
end

% Compute global ripple intervals
FR_start = Fast_Ripples(:,3) + (loop_index - 1) * block_size;
FR_end   = FR_start + Fast_Ripples(:,4);

% Vectorized overlap check
s_start = samples(:,1)';
s_end   = samples(:,2)';

overlap_matrix = (FR_start <= s_end) & (FR_end >= s_start);  % NxM
reject = any(overlap_matrix, 2);  % N x 1

% Remove overlapping ripples
FR_samples_removed = Fast_Ripples(~reject, :);

disp(['--- Rejection of ' sample_type ' samples completed ---']);

end