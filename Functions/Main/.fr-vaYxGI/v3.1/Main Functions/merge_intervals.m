function merged_samples = merge_intervals(seizure_samples, artefact_samples)

% Ensure inputs are Nx2, even if empty
if isempty(artefact_samples)
    artefact_samples = zeros(0, 2);
end
if isempty(seizure_samples)
    seizure_samples = zeros(0, 2);
end

% Case 1: Both are empty
if isempty(artefact_samples) && isempty(seizure_samples)
    merged_samples = zeros(0, 2);
    return;
end

% Case 2: No seizures → return artefacts as-is
if isempty(seizure_samples)
    merged_samples = artefact_samples;
    return;
end

% Case 3: No artefacts → return seizures as-is
if isempty(artefact_samples)
    merged_samples = seizure_samples;
    return;
end

% Step 1: Build pairwise overlap matrix
% Conditions for overlap: (artefact_start < seizure_end) & (artefact_end > seizure_start)
overlap = (artefact_samples(:,1) <= seizure_samples(:,2)') & (artefact_samples(:,2) >= seizure_samples(:,1)');  % n_art x n_sz

% Step 2: Merge overlapping artefacts with seizures
merged_intervals = [];

for j = 1:size(seizure_samples, 1)
    % Find artefacts that overlap seizure j
    overlapping_idx = find(overlap(:,j));
    
    if isempty(overlapping_idx)
        % No artefact overlaps → add seizure as-is
        merged = seizure_samples(j,:);
    else
        % Merge all overlapping artefacts + this seizure
        start_pts = [seizure_samples(j,1); artefact_samples(overlapping_idx,1)];
        end_pts   = [seizure_samples(j,2); artefact_samples(overlapping_idx,2)];
        merged = [min(start_pts), max(end_pts)];
    end
    merged_intervals = cat(1,merged_intervals, merged);
end

% Step 3: Add artefacts that don't overlap any seizure
artefacts_to_add = artefact_samples(~any(overlap, 2), :);

% Step 4: Combine and sort results
merged_samples = sortrows([merged_intervals; artefacts_to_add], 1);
end