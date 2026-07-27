

subj_num = 41; % subject number
data_dir = "/projects3/EPIHFO/EPIHFO/Pat" + string(subj_num);
fs = 2048;
windowSize = 3*fs;

excelfile = fullfile(data_dir, "CNN_map_pat" + subj_num + ".xlsx");

CNN_probabilities_fromexcel = readmatrix(excelfile, 'Sheet', 'CNN_probabilities');
artefact_samples = readmatrix(excelfile, 'Sheet', 'artefact_samples');
sample_window = readmatrix(excelfile, 'Sheet', 'sample_window');
s = floor(sample_window(1,1)/windowSize)+1;
len_samples = sum(sample_window(2,:)) - sample_window(1,1);
e = floor(len_samples/windowSize)+1;
CNN_probabilities_cut = CNN_probabilities_fromexcel(:,s:e);
total_per_t = sum(CNN_probabilities_cut,1);
total_per_c = sum(CNN_probabilities_cut,2);

filename = "/projects3/EPIHFO/EPIHFO/Pat" + string(subj_num) + "/detection_rates_pat"+string(subj_num)+".xls";
badchannels = table2array(readtable(filename,"Sheet", "files combined", "Range","C11:C200",'VariableNamingRule','preserve'));
badchannels(71) = 0;
% shift artefact samples to be relative to analysis start
artefact_samples_shifted = artefact_samples - sample_window(1);

% clip any artefacts that fall outside the analyzed window (safety check)
artefact_samples_shifted(artefact_samples_shifted < 0) = 0;
analyzed_length = len_samples+1;
artefact_samples_shifted(artefact_samples_shifted > analyzed_length) = analyzed_length;

% convert shifted artefact samples into segment/timepoint units (matching CNN_probabilities columns)
artefact_segments_shifted = artefact_samples_shifted / windowSize; % fractional segment index, x-axis units

% build time axis for CNN_probabilities columns (in seconds, for readable labeling)
nTimepoints = size(CNN_probabilities_cut,2);
time_axis_sec = (0:nTimepoints-1) * 3; % each column = 3s segment
%%
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
imagesc(time_axis_sec, 1:size(CNN_probabilities_cut,1), CNN_probabilities_cut);
colormap(ax_main,flipud(gray)); % or 'parula', 'jet' - hot works nicely for probability-style data
cb = colorbar;
ylabel(cb, 'Artifact probability', 'Rotation',90,'FontSize',13)
caxis([0 1]); % assuming probabilities range 0-1
xlabel('Time (s)',FontSize=13);
ylabel('Channel',FontSize=13);
title(sprintf('CNN artifact probability map - Patient %d', subj_num));
hold on;

nChannels = size(CNN_probabilities_cut,1);
% mark artefact times with vertical lines across all channels
for i = 1:size(artefact_segments_shifted,1)
    art_start_sec = artefact_segments_shifted(i,1) * 3; % convert segment -> seconds
    art_end_sec   = artefact_segments_shifted(i,2) * 3;
    
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