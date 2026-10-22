function plot_probabilitites(CNN_probabilities, artefact_samples, bad_chan_idx)

total_per_t = sum(CNN_probabilities,1);
total_per_c = sum(CNN_probabilities,2);

artefact_segments = artefact_samples / 3; % from seconds to "block size"

% build time axis for CNN_probabilities columns (in seconds, for readable labeling)
nTimepoints = size(CNN_probabilities,2);
time_axis_sec = (0:nTimepoints-1) * 3; % each column = 3s segment

% plot heatmap
figure('Position',[100 100 1000 600]);
tiledlayout(8,10,'TileSpacing','compact','Padding','compact');

% top: sum per timepoint
ax_top = nexttile(1,[2 9]);
plot(time_axis_sec, total_per_t, 'k-', 'LineWidth', 1);
hold(ax_top, 'on');
yline(ax_top, 3.3, 'r--', 'LineWidth', 1); % threshold reference
xlim([time_axis_sec(1) time_axis_sec(end)]);
ylabel('Sum of probabilities');
title('Total artifact probability');
set(ax_top,'XTickLabel',[]);
for i = 1:size(artefact_segments,1)
    art_start_sec = artefact_segments(i,1) * 3; % convert segment -> seconds
    art_end_sec   = artefact_segments(i,2) * 3;
    
    a = patch([art_start_sec art_end_sec art_end_sec art_start_sec], ...
         [0.5 0.5 max(total_per_t)+0.5 max(total_per_t)+0.5], ...
         'cyan', 'FaceAlpha', 0.25, 'EdgeColor', 'none');
end

% main 
ax_main = nexttile(21,[6,9]); % rows 2-4, columns 1-4
imagesc(time_axis_sec, 1:size(CNN_probabilities,1), CNN_probabilities);
colormap(ax_main,flipud(gray));
cb = colorbar;
ylabel(cb, 'Artifact probability', 'Rotation',90,'FontSize',13)
caxis([0 1]); 
xlabel('Time (s)',FontSize=13);
ylabel('Channel',FontSize=13);
title(sprintf('CNN artifact probability map - Patient %d', subj_num));
hold on;

nChannels = size(CNN_probabilities,1);
% mark artefact times with vertical lines across all channels
for i = 1:size(artefact_segments,1)
    art_start_sec = artefact_segments(i,1) * 3; % convert segment -> seconds
    art_end_sec   = artefact_segments(i,2) * 3;
    
    a = patch([art_start_sec art_end_sec art_end_sec art_start_sec], ...
         [0.5 0.5 nChannels+0.5 nChannels+0.5], ...
         'cyan', 'FaceAlpha', 0.25, 'EdgeColor', 'none');
end

% add red lines for bad channels
for ch = bad_chan_idx'
    b = yline(ch, 'r-', 'LineWidth', 1);
end

legend([a,b],{'Artefact','Bad channel'}, 'Location', 'best');

% right: sum per channel
ax_right = nexttile(20,[7 1]); % rows 2-4, column 5
plot(total_per_c, 1:nChannels, 'k-', 'LineWidth', 1);
set(ax_right,'YDir','reverse');
grid on;
ylim([0.5 nChannels+0.5]);
xlabel('Sum of probabilities');
set(ax_right,'YTickLabel',[]); 

% link axes
linkaxes([ax_top, ax_main], 'x');
linkaxes([ax_main, ax_right], 'y');