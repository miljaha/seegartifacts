function visualize_threshold_badchannels(badchannels, total_per_c, badchan_peaks, th)

    badchannels = double(badchannels);
    figure;
    chans = 1:size(badchannels,1); % time axis in seconds, one point per 3s segment
    
    hold on
    
    % --- plot the signal ---
    pl = plot(chans, total_per_c, 'b-', 'LineWidth', 1);

    % --- shade the TRUE bad channels ---
    bad_idx = find(badchannels);
    for j = 1:length(bad_idx)
        tru = xline(bad_idx(j),'--r', LineWidth=2);
    end
    
    % --- plot the robust z threshold line, converted back into signal units ---
    thresh_val = med + th * MAD / 0.6745;  % inverse of your z-score formula
    thre = yline(thresh_val, 'k--', 'LineWidth', 1.2);
    
    % --- mark detected peaks ---
    det = plot(chans(badchan_peaks), total_per_c(badchan_peaks), 'ro', 'MarkerFaceColor','r', 'MarkerSize', 5);
    
    xlabel('Channels')
    ylabel('Mean CNN probability')
    title(sprintf('Subject %d: signal vs threshold vs true artifacts', subj_num))
    legend({pl,tru,thre,det},{'Signal','Bad channels','Threshold ('+string(th)+' MAD-z)','Detected peaks'}, 'Location','best')
    hold off
end