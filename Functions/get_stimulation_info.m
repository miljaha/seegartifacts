function [trigger_signal, ch_stimulation_events, stimulation_details, ...
    stimulation_current, stimulation_frequency, requested_current_idx, ...
    requested_frequency_idx, events] = get_stimulation_info(trigger_sig, label, events, ...
    bipolar_labels, requested_current, requested_frequency, sample_window)
%%% Updated on 18.6.2026 by Mohammad Al-Sa'd
events(([events.sample] < sample_window(1)) | ([events.sample] > sample_window(2))) = []; % remove events outside the requested datetime range
[~, bipo_inds, ~] = bipolar_montage_indices(label); % get montage indices
bipolar_labels_rev = lower(string([char(label{bipo_inds(:,2)}) ...
    repelem('-',length(bipo_inds),1) char(label{bipo_inds(:,1)})])); % Get reversed bipolar labels
bipolar_labels_rev = erase(bipolar_labels_rev,' ');                  % Remove any empty spaces if exists
trigger_signal = abs(trigger_sig);                                   % Get the absolute value of the trigger signal
ch_stimulation_events = events(contains(lower(erase({events(:).value}," ")),[bipolar_labels, bipolar_labels_rev]));
temp_str = deblank(string({ch_stimulation_events.value}'));

%% Getting stimulation channel information
A = regexp(temp_str, '^(.*?)(?=[0-9]*\.?[0-9]+\s*mA)', 'tokens', 'once'); % Get the channel labels before the current entry (this solves white space problems)
if iscell(A)
    idx_missing = cellfun(@isempty, A);
    if any(idx_missing) % fallback only for rare format: "m A"
        A_fix = regexp(temp_str(idx_missing),'^(.*?)(?=[0-9]*\.?[0-9]+\s*m\s*A)','tokens', 'once');
        A{idx_missing} = A_fix;
    end
    A = string(cellfun(@(x) x{1}, A, 'UniformOutput', false));
else
    idx_missing = isempty(A);
    if any(idx_missing) % fallback only for rare format: "m A"
        A_fix = regexp(temp_str(idx_missing),'^(.*?)(?=[0-9]*\.?[0-9]+\s*m\s*A)','tokens', 'once');
        A(idx_missing) = A_fix;
    end
end
A = erase(strtrim(A), " ");
A(contains(lower(A),bipolar_labels_rev)) = extractAfter(A(contains(lower(A),bipolar_labels_rev)),'-') + ...
    "-" + extractBefore(A(contains(lower(A),bipolar_labels_rev)),'-');                                  % Correct the channel ordering if needed

%% Getting stimulation current information
tokens = regexp(temp_str,'([0-9]*\.?[0-9]+)\s*mA','tokens','once');
if iscell(tokens)
    idx_missing = cellfun(@isempty, tokens);
    if any(idx_missing) % fallback only for rare format: "m A"
        B_fix = regexp(temp_str(idx_missing),'([0-9]*\.?[0-9]+)\s*m\s*A','tokens', 'once');
        tokens{idx_missing} = B_fix;
    end
    B = string(cellfun(@(x) x{1}, tokens, 'UniformOutput', false));
else
    idx_missing = isempty(tokens);
    if any(idx_missing) % fallback only for rare format: "m A"
        B_fix = regexp(temp_str(idx_missing),'([0-9]*\.?[0-9]+)\s*m\s*A','tokens', 'once');
        tokens(idx_missing) = B_fix;
    end
    B = tokens;
end

%% Getting stimulation frequency information
tokens = regexp(temp_str,'([0-9]*\.?[0-9]+)\s*Hz','tokens','once');
C = strings(size(temp_str));
idx = ~cellfun(@isempty, tokens);
if iscell(tokens)
    C(idx) = cellfun(@(x) string(x{1}), tokens(idx));
else
    C(idx) =  tokens(idx);
end
if all(strcmp(C,'')) || sum(idx) < size(B,1) % if using the old version of annotations
    C = extractAfter(erase(extractAfter(temp_str,' '),' '),'mA');                                       % Get the stimulation frequency
    C(C == "5") = "50";                                                                                 % Correct truncated frequency
end

%% Gather all extracted information
stimulation_details     = [A, B, C];                                                                    % Extract the stimulation details, [channel, current, frequency]
stimulation_current     = double(string(regexp(B, '[+-]?\d+\.?\d*', 'match')));                         % Extract the stimulation current
stimulation_frequency   = double(string(regexp(C, '[+-]?\d+\.?\d*', 'match')));                         % Extract the stimulation frequency
requested_current_idx   = requested_current   == stimulation_current;                                   % Find the stimulation channels with the requested current
requested_frequency_idx = requested_frequency == stimulation_frequency;                                 % Find the stimulation channels with the requested frequency
ch_stimulation_events   = ch_stimulation_events(requested_current_idx & requested_frequency_idx);       % Extract the requested stimulation channels
end