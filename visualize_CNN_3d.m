subj_nums = [23];
class_names = {'Class 1','Class 2','Class 3'};

for subj_num = subj_nums
    data_dir = "/projects3/EPIHFO/EPIHFO/CNN results/Pat" + string(subj_num);
    load(data_dir);
    CNN_probabilities_3d = CNNresults.CNN_map;
    artefact_samples = CNNresults.artefact_samples;
    badchannels = CNNresults.badchannels;
    sleep_samples = CNNresults.sleep_samples;

    nChannels = size(CNN_probabilities_3d,1);
    nTimepoints = size(CNN_probabilities_3d,2);
    time_axis_sec = (0:nTimepoints-1) * 3;

    nRows = 8;
    nCols = 30;

    figure('Position',[50 50 2400 600]);
    t = tiledlayout(nRows,nCols,'TileSpacing','compact','Padding','compact');

    for class_idx = 1:3
        CNN_probabilities = squeeze(CNN_probabilities_3d(:,:,class_idx));
        total_per_t = sum(CNN_probabilities,1);
        total_per_c = sum(CNN_probabilities,2);

        col_start = (class_idx-1)*10 + 1; % 1, 11, 21

        % top: sum per timepoint - row 1, columns col_start:col_start+8
        top_tile = col_start; % row 1 tile index = column number itself
        ax_top = nexttile(top_tile,[1 9]);
        plot(time_axis_sec, total_per_t, 'k-', 'LineWidth', 1);
        xlim([time_axis_sec(1) time_axis_sec(end)]);
        ylabel('Sum of probs');
        title(class_names{class_idx});
        set(ax_top,'XTickLabel',[]);

        % main heatmap - row 2, columns col_start:col_start+8
        main_tile = nCols + col_start; % row 2 starts at index nCols+1
        ax_main = nexttile(main_tile,[7,9]);
        imagesc(time_axis_sec, 1:nChannels, CNN_probabilities);
        colormap(ax_main,flipud(gray));
        cb = colorbar;
        ylabel(cb, 'Artifact probability', 'Rotation',90,'FontSize',11)
        caxis([0 1]);
        xlabel('Time (s)',FontSize=11);
        ylabel('Channel',FontSize=11);
        hold on;

        for i = 1:size(artefact_samples,1)
            art_start_sec = artefact_samples(i,1) / 2048;
            art_end_sec   = artefact_samples(i,2) / 2048;
            a = patch([art_start_sec art_end_sec art_end_sec art_start_sec], ...
                 [0.5 0.5 nChannels+0.5 nChannels+0.5], ...
                 'cyan', 'FaceAlpha', 0.25, 'EdgeColor', 'none');
        end
        bad_chan_idx = find(badchannels == 1);
        for ch = bad_chan_idx'
            b = yline(ch, 'r-', 'LineWidth', 1);
        end
        if class_idx == 1
            legend([a,b],{'Artefact','Bad channel'}, 'Location', 'best');
        end

        % right: sum per channel - row 2, column col_start+9
        right_tile = nCols + col_start + 9;
        ax_right = nexttile(right_tile,[7 1]);
        plot(total_per_c, 1:nChannels, 'k-', 'LineWidth', 1);
        set(ax_right,'YDir','reverse');
        grid on;
        ylim([0.5 nChannels+0.5]);
        xlabel('Sum');
        set(ax_right,'YTickLabel',[]);

        linkaxes([ax_top, ax_main], 'x');
        linkaxes([ax_main, ax_right], 'y');
    end

    sgtitle(sprintf('CNN artifact probability map - Patient %d', subj_num), 'FontSize', 14);

    name = "/projects3/EPIHFO/EPIHFO/CNN results/Pat" + string(subj_num) +"CNN_resized_samples2.png";
    saveas(gcf, name);
end