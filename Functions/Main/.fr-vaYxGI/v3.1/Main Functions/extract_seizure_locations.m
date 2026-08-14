function [seizure_samples, overflow_start, overflow_end] = extract_seizure_locations(events, N, fs, buffered_start, buffered_end, is_looped)
%%% Updated on 6.7.2026 by Mohammad Al-Sa'd
% Extract seizure segments with pre/post buffers from EDF annotations
% Adds buffer before/after seizures, handles spillover between EDF files.

% Initialize outputs
seizure_samples = [];
overflow_start = 0;
overflow_end = 0;

% Parameters
buffer_time = 5*60*fs; % 5 min buffer in samples

% Extract only seizure-related events
disp('--- Extracting seizure segments from manual annotations ---');
idx = strcmpi({events.value},'sz') | strcmpi({events.value},'%');
candidate_events = events(idx);

% Proceed if there are any seizure marks or buffer requests
if ~isempty(candidate_events) || buffered_start > 0 || buffered_end > 0
    
    if ~isempty(candidate_events) % Go through all marked seizures
        disp('Seizure marks detected in the current file');

        % Extract seizure start/end samples from events
        starts = [candidate_events(strcmpi({candidate_events.value},'sz')).sample]';
        ends   = [candidate_events(strcmpi({candidate_events.value},'%')).sample]';
       
        % Handle imbalanced cases
        added_start = false;
        added_end = false;
        if isempty(starts) % No 'Sz' exists in the annotation file (we have only '%')
            starts = 1;
            added_start = true;
            warning('Seizure start mark is missing! The first sample is automatically selected')
        end
        if isempty(ends) % No '%' exists in the annotation file (we have only 'Sz')
            ends = N;
            added_end = true;
            warning('Seizure end mark is missing! The last sample is automatically selected')
        end
        if starts(1) > ends(1) % First seizure start mark is missing, e.g. {'%','Sz','%','Sz','%'}
            starts = [1; starts];
            added_start = true;
            warning('The first seizure start mark is missing! The first sample is automatically selected')
        end
        if starts(end) > ends(end) % Last seizure end mark is missing, e.g. {'Sz','%','Sz','%','Sz'}
            ends = [ends; N];
            added_end = true;
            warning('the last seizure end mark is missing! The last sample is automatically selected')
        end

        % Validate seizure start/end pairings
        if numel(starts) ~= numel(ends)
            error('Mismatched seizure start and end markers. Check annotations!');
        end

        % Apply buffering and build seizure interval list
        seizure_samples = [starts - buffer_time, ends + buffer_time];

        % Check if buffered seizure should start in previous file
        if ~isempty(starts) && seizure_samples(1,1) < 1
            if ~added_start % if we did not add a missing start, i.e., seizure start is annotated
                overflow_start = abs(seizure_samples(1,1)) + 1; % calculate the amount of data required from the previous file
                fprintf('\n Buffered seizure overflows to the previous file for %0.4f seconds\n',(overflow_start-1)/fs);
            end
            over_idx = seizure_samples(:,1) < 1; % identify which seizure segments overflow to the previous file
            seizure_samples(over_idx,1) = 1; % correct the start of any overflowing seizure segment
        end

        % Check if buffered seizure end time overflows to next file
        if ~isempty(ends) && seizure_samples(end,2) > N
            if ~added_end % if we did not add a missing end, i.e., seizure end is annotated
                overflow_end = seizure_samples(end,2) - N; % calculate the amount of data required from the next file
                fprintf('\n Buffered seizure overflows to the next file for %0.4f seconds\n',(overflow_end-1)/fs);
            end
            over_idx = seizure_samples(:,2) > N; % identify which seizure segments overflow to the next file
            seizure_samples(over_idx,2) = N; % correct the end of any overflowing seizure segment
        end
    end

    % Add overflow from next file
    if buffered_start > 0
        seizure_samples = [seizure_samples; [N - buffered_start, N]]; % add a new seizure event from the next file
        disp('Overflow from next file detected. Adding to the end of the current file');
    end

    % Add overflow from previous file (if not in backward reprocessing mode)
    if buffered_end > 0 && ~is_looped
        seizure_samples = [[1, buffered_end]; seizure_samples]; % add a new seizure event from the previous file
        disp('Overflow from previous file detected. Adding to the start of the current file');
    end

else
    disp('No seizures or overflow buffers found');
end

%% Report summary
nSeg = size(seizure_samples,1);
if nSeg > 0
    fprintf('Seizure segments found: %d\n', nSeg);
    durations = (seizure_samples(:,2) - seizure_samples(:,1)) / fs;
    for i = 1:nSeg
        fprintf('#%d duration (s): %0.4f\n', i, durations(i));
    end
    fprintf('Total buffered duration (min): %0.4f\n', sum(durations)/60);
    fprintf('Total provision (%%): %0.4f\n', 100*sum(fs*durations)/N);
end
disp('--- Seizure extraction completed ---');
end