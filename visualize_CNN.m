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

% plot heatmap
figure('Position',[100 100 1000 600]);
imagesc(time_axis_sec, 1:size(CNN_probabilities_cut,1), CNN_probabilities_cut);
colormap(flipud(gray)); % or 'parula', 'jet' - hot works nicely for probability-style data
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
    
    patch([art_start_sec art_end_sec art_end_sec art_start_sec], ...
         [0.5 0.5 nChannels+0.5 nChannels+0.5], ...
         'cyan', 'FaceAlpha', 0.25, 'EdgeColor', 'none');
end

legend('Artifact region', 'Location', 'best');