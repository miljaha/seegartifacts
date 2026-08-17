subj_num = 44; % subject number
data_dir = "/projects3/EPIHFO/EPIHFO/CNN results/Pat" + string(subj_num)+"retnew";
fs = 2048;
windowSize = 3*fs;

load(data_dir);

CNN_probabilities = CNNresults.CNN_map(:,:,1);
artefact_samples = CNNresults.artefact_samples;
badchannels = CNNresults.badchannels;
sleep_samples = CNNresults.sleep_samples;
% CNNresults = struct('CNN_map',CNN_probabilities,'artefact_samples',artifact_samples_all,'badchannels',badchannels,'sleep_samples',sleep_samples);

total_per_t = sum(CNN_probabilities,1);
total_per_c = sum(CNN_probabilities,2);

% shift artefact samples to be relative to analysis start

% convert shifted artefact samples into segment/timepoint units (matching CNN_probabilities columns)
artefact_segments = artefact_samples / windowSize; % fractional segment index, x-axis units

% build time axis for CNN_probabilities columns (in seconds, for readable labeling)
nTimepoints = size(CNN_probabilities,2);
time_axis_sec = (0:nTimepoints-1) * 3; % each column = 3s segment
%
% plot heatmap
figure('Position',[100 100 1000 600]);
t = tiledlayout(8,10,'TileSpacing','compact','Padding','compact');

% top: sum per timepoint
ax_top = nexttile(1,[1 9]); % spans top row, 4 of 5 columns (leaves room for right marginal)
plot(time_axis_sec, total_per_t, 'k-', 'LineWidth', 1);
xlim([time_axis_sec(1) time_axis_sec(end)]);
ylabel('Sum of probabilities');
title('Total artifact probability');
set(ax_top,'XTickLabel',[]); % hide x labels here, main heatmap below shows them

% main 
ax_main = nexttile(11,[7,9]); % rows 2-4, columns 1-4
imagesc(time_axis_sec, 1:size(CNN_probabilities,1), CNN_probabilities);
colormap(ax_main,flipud(gray)); % or 'parula', 'jet' - hot works nicely for probability-style data
cb = colorbar;
ylabel(cb, 'Artifact probability', 'Rotation',90,'FontSize',13)
caxis([0 1]); % assuming probabilities range 0-1
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
bad_chan_idx = find(badchannels == 1); % row indices of bad channels
for ch = bad_chan_idx'
    b = yline(ch, 'r-', 'LineWidth', 1);
end

legend([a,b],{'Artefact','Bad channel'}, 'Location', 'best');

% right: sum per channel
ax_right = nexttile(20,[7 1]); % rows 2-4, column 5
plot(total_per_c, 1:nChannels, 'k-', 'LineWidth', 1);
set(ax_right,'YDir','reverse'); % match main heatmap orientation
grid on;
ylim([0.5 nChannels+0.5]);
xlabel('Sum of probabilities');
set(ax_right,'YTickLabel',[]); % hide y labels here, main heatmap shows channel numbers

% link axes so zoom/pan stays aligned
linkaxes([ax_top, ax_main], 'x');
linkaxes([ax_main, ax_right], 'y');

%% numerical

true_artefacts = zeros(1, nTimepoints);

 % which segments overlap artefacts
for a = 1:size(artefact_segments,1)
    start_t = artefact_segments(a,1);
    end_t   = artefact_segments(a,2);
    
    seg_start = floor(start_t);              % which segment the artefact starts in
    
    % if end_t lands exactly on a boundary (e.g. 18.0), it does NOT spill into
    % the next segment -> subtract a tiny epsilon before ceil, or use this trick:
    seg_end = ceil(end_t) - 1;
    if seg_end < seg_start
        seg_end = seg_start;
    end
    idx_start = seg_start + 1;  % +1 because segment "0" = time [0,1) = array index 1
    idx_end   = seg_end + 1;
    
    idx_start = max(idx_start, 1);
    idx_end   = min(idx_end, nTimepoints);
    
    true_artefacts(idx_start:idx_end) = 1;
end

best_threshold = 0.13*max(total_per_t);
above_limit = total_per_t > best_threshold;
    
TP = sum(above_limit == 1 & true_artefacts == 1);
FP = sum(above_limit == 1 & true_artefacts == 0);
FN = sum(above_limit == 0 & true_artefacts == 1);
TN = sum(above_limit == 0 & true_artefacts == 0);

precision = TP / (TP + FP + eps);
recall    = TP / (TP + FN + eps);
F1        = 2 * precision * recall/ (precision + recall + eps);

