function artefact_samples = extract_artefact_locations(events, N, fs)
%% Extract artefact segments from EDF annotations
% INPUT:
%   events : Struct array of annotations
%   hdr    : Header with fields nSamples and fs
%
% OUTPUT:
%   artefact_samples : Kx2 matrix of [start, end] samples, K is the number
%                      of artifact segments.

disp('--- Extracting artefact segments from manual annotations ---');

% Extract only artefact-related events
events = events(contains(lower({events.value}), {'artefact','artefakta'}));
if isempty(events) % no valid annotations in events
    disp('No artefacts marked in the file');
    artefact_samples = [];
    return;
end

% Extract artefact start/end samples from events
starts = [events(contains(lower({events.value}), {'start','alku'})).sample]';
ends   = [events(contains(lower({events.value}), {'end','loppu'})).sample]';

% Handle imbalanced cases
if isempty(starts), starts = 1; end
if isempty(ends),   ends = N; end
if starts(1) > ends(1), starts = [1; starts]; end
if starts(end) > ends(end), ends = [ends; N]; end

% Validate pairing
if numel(starts) ~= numel(ends)
    error('Mismatched artefact start/end markers. Check annotations!');
end
artefact_samples = [starts(:), ends(:)];

% Validate temporal order
x = artefact_samples';
if any(diff(x(:)) <= 0)
    error('Artefact samples not in chronological order.');
end

%% Display summary
fprintf('Artefact segments found: %d\n', size(artefact_samples,1));
durations = (artefact_samples(:,2) - artefact_samples(:,1)) / fs;
for i = 1:length(durations)
    fprintf('#%d duration (s): %.4f\n', i, durations(i));
end
fprintf('Total duration (min): %.4f\n', sum(durations)/60);
fprintf('Total provision (%%): %.4f\n', 100*sum(fs*durations)/N);
disp('--- Artefact extraction completed ---');
end
