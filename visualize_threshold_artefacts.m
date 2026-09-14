%% visualize the average artefact probability across time, the threshold for artifact cassification and found artifacts
function visualize_threshold_artefacts(subj_num, th)

    resultsname = '/projects3/EPIHFO/EPIHFO/seegartifacts/LOSO/probabilitymap_Pat'+string(subj_num)+'_results_sleeptimes.mat';
    load(resultsname)

    CNN_probabilities = results.map;
    total_per_t = log1p(mean(CNN_probabilities,1));

    artefact_segments = results.artefacts;

    % --- artifacts (time) ---
    med = median(total_per_t);
    MAD = median(abs(total_per_t - med));
    robust_z = 0.6745 * (total_per_t - med) / MAD;
    artefact_peaks = robust_z > th;

    nSegments = length(total_per_t);
    artefact_vec = zeros(1, nSegments);
    
    for j = 1:size(artefact_segments,1)
            startSeg = max(floor(artefact_segments(j,1)/3)+1, 1);
            endSeg = min(ceil(artefact_segments(j,2)/3), nSegments);
            artefact_vec(startSeg:endSeg) = 1;
    end

    figure;
    nSegments = length(total_per_t);
    t = (0:nSegments-1) * 3; % time axis in seconds, one point per 3s segment
    
    % --- shade the TRUE artifact regions first (so they sit behind everything) ---
    hold on
    artefact_idx = find(artefact_vec);
    if ~isempty(artefact_idx)
        % find contiguous blocks so we don't draw nSegments individual patches
        d = diff([0 artefact_vec 0]);
        blockStart = find(d==1);
        blockEnd = find(d==-1)-1;
        for b = 1:length(blockStart)
            xStart = t(blockStart(b));
            xEnd = t(blockEnd(b)) + 3; % +3 to cover the full segment width
            patch([xStart xEnd xEnd xStart], [min(total_per_t) min(total_per_t) max(total_per_t) max(total_per_t)], ...
                [1 0.8 0.8], 'EdgeColor','none', 'FaceAlpha',0.5, 'HandleVisibility','off');
        end
    end
    
    % --- plot the signal ---
    plot(t, total_per_t, 'b-', 'LineWidth', 1);
    
    % --- plot the robust z threshold line, converted back into signal units ---
    thresh_val = med + th * MAD / 0.6745;  % inverse of your z-score formula
    yline(thresh_val, 'k--', 'LineWidth', 1.2);
    
    % --- mark detected peaks ---
    plot(t(artefact_peaks), total_per_t(artefact_peaks), 'ro', 'MarkerFaceColor','r', 'MarkerSize', 5);
    
    xlabel('Time (s)')
    ylabel('Mean CNN probability')
    title(sprintf('Subject %d: signal vs threshold vs true artifacts', subj_num))
    legend('Signal','Threshold ('+string(th)+' MAD-z)','Detected peaks', 'Location','best')
    hold off

end
