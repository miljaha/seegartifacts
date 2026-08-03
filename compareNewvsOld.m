subj_nums = [22];%,23]; % subject number
% 12,19,20,21,22,23,24,25,26,27,28,29,30

for subj_num = subj_nums
    data_dir = "/projects3/EPIHFO/EPIHFO/CNN results/Pat" + string(subj_num)+"_new";
    load(data_dir);
    
    CNN_probabilities_new = CNNresults.CNN_map;
    artefact_samples = CNNresults.artefact_samples;
    badchannels = CNNresults.badchannels;
  
    data_dir = "/projects3/EPIHFO/EPIHFO/CNN results/Pat" + string(subj_num);
    load(data_dir)
    CNN_probabilities_old = CNNresults.CNN_map;

    total_per_c_new = sum(CNN_probabilities_new,2);
    total_per_c_old = sum(CNN_probabilities_old,2);

    total_per_t_new = sum(CNN_probabilities_new,1);
    total_per_t_old = sum(CNN_probabilities_old,1);

    figure;
    sgtitle(sprintf("Summary for subject %d", subj_num))
    subplot(2,1,1);
    plot(total_per_c_old); hold on;
    plot(total_per_c_new)
    bad_chan_idx = find(badchannels == 1); % row indices of bad channels
    for ch = bad_chan_idx'
        b = xline(ch, 'r--', 'LineWidth', 1);
    end
    title("Bad channels")
    legend("Old", "New","Bad");
    xlabel("Channels"); ylabel("Sum of artefacts")

    t = linspace(0,length(total_per_t_old)*3, length(total_per_t_old));
    subplot(2,1,2);
    plot(t,total_per_t_old); hold on;
    plot(t,total_per_t_new)
    title("Artefacts")
    nChannels = size(CNN_probabilities_new,1);
    % mark artefact times with vertical lines across all channels
    for i = 1:size(artefact_segments,1)
        art_start_sec = artefact_segments(i,1) * 3; % convert segment -> seconds
        art_end_sec   = artefact_segments(i,2) * 3;
        
        a = patch([art_start_sec art_end_sec art_end_sec art_start_sec], ...
             [0.5 0.5 nChannels+0.5 nChannels+0.5], ...
             'cyan', 'FaceAlpha', 0.25, 'EdgeColor', 'none');
    end
    xlim([0,length(t)])
    xlabel("Time (s)"); ylabel("Sum of artefacts")
    legend("Old", "New","Artefacts");

end