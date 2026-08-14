function spikes_in_ripples = find_spikes_in_ripples(ripples, spikes, L)
% Construct ripple intervals with buffer of length L
ripple_chan  = ripples(:,1);
ripple_start = ripples(:,3) - L;
ripple_end   = ripples(:,3) + ripples(:,4) + L;
% Spike channel and position
spike_chan  = spikes(:,1);
spike_start = spikes(:,3);
% Broadcasted comparisons
same_channel = spike_chan == ripple_chan';
within_range = (spike_start >= ripple_start') & ...
               (spike_start <= ripple_end');
% A spike is in ripple if any matching interval on same channel
spike_in_ripple = any(same_channel & within_range, 2); % [N x 1]
% Return only matching spikes
spikes_in_ripples = spikes(spike_in_ripple, :);
end