function [seizure_samples, overflow_start, overflow_end] = extract_artefact_locations2(events, N, fs, buffered_start, buffered_end, is_looped, start_sample, end_sample)
% Extract seizure segments with pre/post buffers from EDF annotations
% Adds buffer before/after seizures, handles spillover between EDF files.

% Initialize outputs
seizure_samples = [];
overflow_start = 0;
overflow_end = 0;

% Parameters
buffer_time = 5*60*fs; % 5 min buffer in samples

% Extract only seizure-related events
disp('--- Extracting artefact segments from manual annotations ---');
idx = contains(lower({events.value}),{'artefact','artefakta'});
candidate_events = events(idx);

% Proceed if there are any seizure marks or buffer requests
if ~isempty(candidate_events) || buffered_start > 0 || buffered_end > 0
    
    if ~isempty(candidate_events) % Go through all marked seizures
        disp('Seizure marks detected in the current file.');

        % Extract seizure start/end samples from events
        starts = [candidate_events(contains(lower({candidate_events.value}),{'start','alku'})).sample]';
        fprintf("Starts:\n")
        disp(starts)
        ends   = [candidate_events(contains(lower({candidate_events.value}),{'end','loppu'})).sample]';
        fprintf("Ends\n")
        disp(ends)
       
        % Handle imbalanced cases
        added_start = false;
        added_end = false;
        if isempty(starts) % No 'Sz' exists in the annotation file (we have only '%')
            starts = 1;
            added_start = true;
            warning('Artefact start mark is missing! The first sample is automatically selected.')
        end
        if isempty(ends) % No '%' exists in the annotation file (we have only 'Sz')
            ends = N;
            added_end = true;
            warning('Artefact end mark is missing! The last sample is automatically selected.')
        end
        if starts(1) > ends(1) % First seizure start mark is missing, e.g. {'%','Sz','%','Sz','%'}
            starts = [1; starts];
            added_start = true;
            warning('The first artefact start mark is missing! The first sample is automatically selected.')
        end
        if starts(end) > ends(end) % Last seizure end mark is missing, e.g. {'Sz','%','Sz','%','Sz'}
            ends = [ends; N];
            added_end = true;
            warning('the last artefact end mark is missing! The last sample is automatically selected.')
        end

        % Validate seizure start/end pairings
        if numel(starts) ~= numel(ends)
            error('Mismatched artefact start and end markers. Check annotations!');
        end

        % Apply buffering and build seizure interval list
        seizure_samples = [starts - buffer_time, ends + buffer_time];

        % Check if buffered seizure should start in previous file
        if ~isempty(starts) && seizure_samples(1,1) < 1 && ~added_start
            overflow_start = abs(seizure_samples(1,1)) + 1;
            seizure_samples(1,1) = 1;
            fprintf('\n Buffered artefact overflows to the previous file for %0.4f seconds\n',(overflow_start-1)/fs);
        end

        % Check if buffered seizure end time overflows to next file
        if ~isempty(ends) && seizure_samples(end,2) > N && ~added_end
            overflow_end = seizure_samples(end,2) - N;
            seizure_samples(end,2) = N;
            fprintf('\n Buffered artefact overflows to the next file for %0.4f seconds\n',(overflow_end-1)/fs);
        end

        % Clamp by analysis window
        if start_sample > 0
            seizure_samples(1,1) = max(seizure_samples(1,1), start_sample);
        end
        if end_sample > 0
            seizure_samples(end,2) = min(seizure_samples(end,2), end_sample);
        end
    end

    % Add overflow from next file
    if buffered_start > 0
        seizure_samples = [seizure_samples; [N - buffered_start, N]];
        disp('Overflow from next file detected. Adding to the end of the current file');
    end

    % Add overflow from previous file (if not in backward reprocessing mode)
    if buffered_end > 0 && ~is_looped
        seizure_samples = [[1, buffered_end]; seizure_samples];
        disp('Overflow from previous file detected. Adding to the start of the current file');
    end

else
    disp('No seizures or overflow buffers found.');
end

%% Report summary
nSeg = size(seizure_samples,1);
if nSeg > 0
    fprintf('Artefact segments found: %d\n', nSeg);
    durations = (seizure_samples(:,2) - seizure_samples(:,1)) / fs;
    for i = 1:nSeg
        fprintf('#%d duration (s): %0.4f\n', i, durations(i));
    end
    fprintf('Total buffered duration (min): %0.4f\n', sum(durations)/60);
    fprintf('Total provision (%%): %0.4f\n', 100*sum(fs*durations)/N);
end
disp('--- Artefact extraction completed ---');
end