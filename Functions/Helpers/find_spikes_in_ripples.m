function spikes_in_ripples = find_spikes_in_ripples(ripples, spikes, L)
% Construct ripple intervals with buffer of length L

    if ~(isempty(ripples)) && ~isempty(spikes)
        ripple_chan  = ripples(:,1);
        ripple_start = ripples(:,3);
        ripple_end   = ripples(:,3) + ripples(:,4);
        % Spike channel and position
        spike_chan  = spikes(:,1);
        spike_start = spikes(:,3);
        
        spike_ripples = zeros(length(ripple_start),4);
        
        for r = 1:numel(ripple_start)
            window = (spike_chan == ripple_chan(r)) & ...   % same channel
                (spike_start >= ripple_start(r) - L) & ...   % after start of window
                (spike_start <= ripple_end(r) + L);          % before end of window
        
            spikes_in_window = spike_start(window);
        
            if ~isempty(spikes_in_window)
                start_time = min(ripple_start(r), min(spikes_in_window));
                end_time = max(ripple_end(r), max(spikes_in_window));
        
                duration = end_time - start_time;
        
                spike_ripples(r,:) = [ripple_chan(r), ripples(r,2), start_time, duration]; % [chan, freq, start, dur]
            end
        end
        
        spike_ripples = spike_ripples(any(spike_ripples,2),:);
        spikes_in_ripples = spike_ripples;
    else
        spikes_in_ripples = [];
    end

%{

% Broadcasted comparisons
same_channel = spike_chan == ripple_chan';
within_range = (spike_start >= ripple_start') & ...
               (spike_start <= ripple_end');
% A spike is in ripple if any matching interval on same channel
spike_in_ripple = any(same_channel & within_range, 2); % [N x 1]
% Return only matching spikes
spikes_in_ripples = spikes(spike_in_ripple, :);

%}
end