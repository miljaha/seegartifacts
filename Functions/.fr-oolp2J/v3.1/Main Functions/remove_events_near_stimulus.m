function [event, event_size_org] = remove_events_near_stimulus(event, r_start, r_end, stimulus_removal_window, fs, thresh_perc)
% updated 5.6.2026 by Mohammad Al-Sa'd
event_size_org = size(event,1); % Get the events original size
if ~isempty(event)
    overlap_matrix = (event(:,3) <= r_end') & ((event(:,3) + event(:,4)) >= r_start'); % compute the overlap binary matrix (recording channel x stimulus peaks)
    for i = 1:size(overlap_matrix,2)  % iterate through stimulus peaks
        overlap_idx = find(overlap_matrix(:,i)); % find the overlap indices
        if ~isempty(overlap_idx)
            event_st = event(overlap_idx,3);  % event start sample
            event_fi = event(overlap_idx,3) + event(overlap_idx,4);  % event end sample
            overlap_cond = (min(event_fi,r_end(i)) - max(event_st,r_start(i)))/(stimulus_removal_window*fs + 1) <= thresh_perc; % flag for the overlap ratio
            overlap_matrix(overlap_idx(overlap_cond),i) = false; % make the overlap entry "false" if the duration overlap is not much < thresh_perc
        end
    end
    event = event(~any(overlap_matrix, 2),:); % remove stimulus-overlaped events
end
end