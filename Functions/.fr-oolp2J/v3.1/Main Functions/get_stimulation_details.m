function Summary = get_stimulation_details(trigger_signal, label, ...
    bipolar_labels, events, ch_stimulation_events, fs, sample_window_end, ...
    requested_frequency, requested_current, requested_current_idx, ...
    requested_frequency_idx, stimulation_details, stimulation_current, ...
    stimulation_frequency)

%%% Updated on 4.6.2026 by Mohammad Al-Sa'd

%%% Rough stimulation period calculation
[~, bipo_inds, ~] = bipolar_montage_indices(label); % get montage indices
bipolar_labels_rev = lower(string([char(label{bipo_inds(:,2)}) ...
    repelem('-',length(bipo_inds),1) char(label{bipo_inds(:,1)})])); % Get reversed bipolar labels
bipolar_labels_rev = erase(bipolar_labels_rev,' ');                  % Remove any empty spaces if exists
all_stimulation_events  = events(contains(lower(erase({events(:).value}," ")), ...
    [bipolar_labels; bipolar_labels_rev; "stim"]));                  % Find all stimulation events from annotations

stimulation_start       = [ch_stimulation_events.sample]';                                        % Initiate the stimulation start samples
stimulation_end         = [all_stimulation_events.sample]';                                       % Initiate the stimulation end samples
next_vals = arrayfun(@(xi) stimulation_end(find(stimulation_end > xi, 1, 'first')), ...
    stimulation_start, 'UniformOutput', false);                                                   % Find consecutive end samples
stimulation_samples = sort([stimulation_start; [next_vals{:}]']);                                 % Get the stimulation samples in one array
if stimulation_samples(end) == stimulation_start(end)                                             % Add stimulation ending if needed
    stimulation_samples = cat(1,stimulation_samples, sample_window_end);
end

%%% Fine stimulation period calculation
pulse_time        = 1;                                                 % Pulse duration in seconds
dt_tolerance      = 0.5*pulse_time;                                    % Tolerance in seconds for the pulses locations
trigger_high      = prctile(trigger_signal,55);                        % Get the trigger high level value
stimulation_start = stimulation_samples(1:2:end);                      % Get the annotation-based start time for stimulation
stimulation_end   = stimulation_samples(2:2:end);                      % Get the annotation-based end time for stimulation
num_stimulations  = size(stimulation_start,1);                         % Calculate the number of stimulation cycles
fprintf('--- %d stimulation cycles are detected at %dHz and %dmA ---\n', ...
    num_stimulations, requested_frequency, requested_current);
trigger_pulses = cell(num_stimulations,1);                             % Initiate the pulses variable
for stim_idx = 1:num_stimulations                                      % Iterate through the stimulation cycles
    idx = stimulation_start(stim_idx):stimulation_end(stim_idx);       % Stimulation sample indices
    temp_trigger = trigger_signal(idx,:);                              % Get the stimulatoin part of the trigger signals
    normal_peak  = zeros(size(temp_trigger));                          % Initiate the normal peaks variable
    extreme_peak = zeros(size(temp_trigger));                          % Initiate the extreme peaks variable
    for i = 1:size(temp_trigger,2)                                     % Iterate through the trigger signals
        normal_peak(:,i) = (temp_trigger(:,i) > trigger_high(i)) & ... % Find the pulses with normal amplitude
            (temp_trigger(:,i) < 1.5*trigger_high(i));
        extreme_peak(:,i) = temp_trigger(:,i) >= 1.5*trigger_high(i);  % Find the pulses with extreme amplitude
    end
    trigger_spikes = sum(normal_peak,2) > 0;                           % Merge the normal pulses from all trigger signals
    trigger_extreme_spikes = sum(extreme_peak,2) > 0;                  % Merge the extreme pulses from all trigger signals
    if sum(trigger_spikes) == sum(trigger_extreme_spikes)              % Check that the number of normal and extreme pulses is equal
        fprintf('  Stimulation cycle %d has %d/%d pulses\n', ...
            stim_idx,sum(trigger_spikes),sum(trigger_extreme_spikes));
        trigger_pulses{stim_idx} = find(trigger_spikes) + idx(1) - 1;  % Get the location of stimulation pulses within a cycle
    elseif sum(trigger_extreme_spikes) > sum(trigger_spikes)           % If the number of extreme pulses is more we are missing some pulses
        lineLength = fprintf(2,'  Stimulation cycle %d has %d/%d pulses: ', ...
            stim_idx,sum(trigger_spikes),sum(trigger_extreme_spikes));
        x_onsets = find(trigger_spikes);                               % Find the normal pulses time position
        y_onsets = find(trigger_extreme_spikes);                       % Find the extreme pulses time position
        if ~isempty(x_onsets)
            dt = abs(y_onsets - x_onsets');                            % Compare the time positions
            min_dist = min(dt, [], 2);                                 % Find the minimum distance from each extreme pulse
            add_pulses = min_dist > dt_tolerance*fs;                   % Find the extreme pulses that need adding within a tolerance
            missing_onsets = y_onsets(add_pulses);                     % Find the time position of the pulses that need adding
            recovered_spikes = trigger_spikes;                         % Initiate the recovered pulses variable
            recovered_spikes(missing_onsets) = true;                   % Add the missing pulses
        else
            recovered_spikes = trigger_extreme_spikes;                 % If there are no normal pulses, use the extreme pulses
        end
        trigger_pulses{stim_idx} = find(recovered_spikes) + idx(1)-1;  % Get the location of stimulation pulses within a cycle

        if (sum(recovered_spikes)-sum(trigger_spikes)) == 0
            fprintf(2,repmat('\b',1,lineLength));
            fprintf('  Stimulation cycle %d has %d/%d pulses\n', ...
                stim_idx,sum(trigger_spikes),sum(recovered_spikes));
        else
            fprintf('%d missing pulses are recovered\n', ...
                sum(recovered_spikes)-sum(trigger_spikes));
        end
    else
        trigger_pulses{stim_idx} = find(trigger_spikes) + idx(1) - 1;  % Get the location of stimulation pulses within a cycle
        fprintf(2,'  Stimulation cycle %d has %d/Unknown pulses\n', ...
            stim_idx,sum(trigger_spikes));
    end
end

%%% Generate stimulation summary
Summary = [];
Summary.stimulation_channel_label = upper(stimulation_details(requested_current_idx & requested_frequency_idx,1));  % Extract the requested stimulation channel labels
[ch_flag, Summary.stimulation_channel_number] = ismember(lower(Summary.stimulation_channel_label),bipolar_labels);  % Gather stimulation channel numbers
if any(~ch_flag), error('Some annotated stimulation channels are not part of the input data!'); end                 % Check annotations
Summary.stimulation_current_mA      = stimulation_current(requested_current_idx & requested_frequency_idx);         % Gather stimulation currents
Summary.stimulation_frequency_Hz    = stimulation_frequency(requested_current_idx & requested_frequency_idx);       % Gather stimulation frequencies
Summary.cycle_start_from_annotation = stimulation_samples(1:2:end);        % Gather annotation-based stimulation start samples
Summary.cycle_end_from_annotation   = stimulation_samples(2:2:end);        % Gather annotation-based stimulation end samples
Summary.cycle_start_from_trigger    = cellfun(@min, trigger_pulses);       % Gather trigger-based stimulation start samples
Summary.cycle_end_from_trigger      = cellfun(@max, trigger_pulses) + fs;  % Gather trigger-based stimulation end samples
Summary.cycle_end_from_trigger      = min(Summary.cycle_end_from_trigger, sample_window_end); % Make sure the cycle end is within the requested end datetime
Summary.stimulation_pulses_location = trigger_pulses;                      % Gather the stimulation pulses within each cycle
stims_pat = lower(split(Summary.stimulation_channel_label,'-'));           % Split the stimulation channel labels
if length(Summary.stimulation_channel_label) == 1                          % If a single channel is stimulated make sure stims_pat is a vertical array
    stims_pat = stims_pat';
end
neighbor_channel = cell(num_stimulations,2);               % Initiate the channel neighbor variable
bipolar_labels_1 = extractBefore(bipolar_labels,"-");      % First channel of the bipolar labels
bipolar_labels_2 = extractAfter(bipolar_labels,"-");       % Second channel of the bipolar labels
for i = 1:num_stimulations                                 % Iterate through the stimulation cycles
    flag1 = strcmpi(bipolar_labels_1,stims_pat(i,1)) | strcmpi(bipolar_labels_1,stims_pat(i,2)); % Check which channels has the first part of the stimulation label
    flag2 = strcmpi(bipolar_labels_2,stims_pat(i,1)) | strcmpi(bipolar_labels_2,stims_pat(i,2)); % Check which channels has the second part of the stimulation label
    neighbor_channel{i,1} = upper(bipolar_labels(xor(flag1,flag2),:))';  % Check which channels has either the first or second part of the stimulation label
    [~, neighbor_channel{i,2}] = ismember(lower(neighbor_channel{i,1}),bipolar_labels');  % Calculate the neibhoring channel index
end
Summary.neighbor_channel_labels = neighbor_channel(:,1);  % Get the neighboring channel labels
Summary.neighbor_channel_number = neighbor_channel(:,2);  % Get the neighboring channel numbers
Summary = struct2table(Summary);   % Convert the stimulation summary to table


minimum_num_stimulus = 11;
min_num_stimulus = false(1,num_stimulations);
for stim_idx = 1:num_stimulations % Iterate through the stimulation cycles
    num_of_stims = size(trigger_pulses{stim_idx},1);
    if num_of_stims < minimum_num_stimulus
        fprintf(2,'  Stimulation cycle %d is rejected (< %d peaks)\n',stim_idx,minimum_num_stimulus);
        min_num_stimulus(stim_idx) = false;
    else
        fprintf('  Stimulation cycle %d is accepted\n',stim_idx);
        min_num_stimulus(stim_idx) = true;
    end
end
Summary = Summary(min_num_stimulus,:);
end