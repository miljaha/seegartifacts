excelfile = fullfile(data_dir, "CNN_map_pat" + subj_num + ".xlsx");

CNN_probabilities = readmatrix(excelfile, 'Sheet', 'CNN_probabilities');
artefact_samples = readmatrix(excelfile, 'Sheet', 'artefact_samples');
sample_window = readmatrix(excelfile, 'Sheet', 'sample_window');

%% shift artefact samples to be relative to analysis start
artefact_samples_shifted = artefact_samples - sample_window(1);

% clip any artefacts that fall outside the analyzed window (safety check)
artefact_samples_shifted(artefact_samples_shifted < 0) = 0;
analyzed_length = sample_window(2) - sample_window(1) + 1;
artefact_samples_shifted(artefact_samples_shifted > analyzed_length) = analyzed_length;

%% convert shifted artefact samples into segment/timepoint units (matching CNN_probabilities columns)
windowSize = fs*3; % samples per 3s segment - same fs used when CNN_probabilities was built

artefact_segments_shifted = artefact_samples_shifted / windowSize; % fractional segment index, x-axis units

%% build time axis for CNN_probabilities columns (in seconds, for readable labeling)
nTimepoints = size(CNN_probabilities,2);
time_axis_sec = (0:nTimepoints-1) * 3; % each column = 3s segment

%% plot heatmap
figure('Position',[100 100 1000 600]);
imagesc(time_axis_sec, 1:size(CNN_probabilities,1), CNN_probabilities);
colormap(hot); % or 'parula', 'jet' - hot works nicely for probability-style data
colorbar;
clim([0 1]); % assuming probabilities range 0-1
xlabel('Time (s)');
ylabel('Channel');
title(sprintf('CNN artifact probability map - Patient %d', subj_num));
hold on;

%% mark artefact times with vertical lines across all channels
for i = 1:size(artefact_segments_shifted,1)
    art_start_sec = artefact_segments_shifted(i,1) * 3; % convert segment -> seconds
    art_end_sec   = artefact_segments_shifted(i,2) * 3;
    
    xline(art_start_sec, 'c-', 'LineWidth', 1);
    xline(art_end_sec, 'c--', 'LineWidth', 1);
end

legend('','Artifact start','Artifact end'); % first entry blank for the heatmap itself