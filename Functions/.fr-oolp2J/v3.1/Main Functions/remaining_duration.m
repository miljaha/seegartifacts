function duration = remaining_duration(block_samples, samples, duration_original, fs)
%% Calculates clean block duration after excluding non-overlapping intervals

% If no samples to remove, return original duration
if isempty(samples)
    duration = duration_original;
    return;
end

% Compute start and end of overlaps
intersect_start = max(block_samples(1), samples(:,1));
intersect_end   = min(block_samples(2), samples(:,2));

% Retain only valid overlaps (positive-length intersections)
valid = intersect_end > intersect_start;
overlap_lengths = intersect_end(valid) - intersect_start(valid);

% Subtract overlap durations (in minutes)
duration = duration_original - sum(overlap_lengths) / fs;

% Enforce non-negative output
duration = max(duration, 0);

end