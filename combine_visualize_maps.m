% Read file-specific probability maps, combine them and their manually
% marked artifacts and visualize the data

function combine_visualize_maps(subj_num)

% find saved maps
address = "/projects3/EPIHFO/EPIHFO/seegartifacts/maps/Pat" + string(subj_num);
saved = dir(address + "*");

CNN_map = [];
artefacts = [];
length_previous = 0;

badchannels = patient_data.badchannels;
for k = 1:numel(saved) 
    % load saved map
    load(fullfile(saved(k).folder, saved(k).name));

    % contruct CNN map
    CNN_map = [CNN_map, patient_data.CNNmap];

    % artefact sample is in seconds, and the start is same as each files
    % map
    artefacts = [artefacts; patient_data.artifacts + length_previous];
    length_previous = size(patient_data.broadband,1) ./ 2048;
end

artefact_segments = artefacts / 3; % fractional segment index, x-axis units
nTimepoints = size(CNN_map,2);
time_axis_sec = (0:nTimepoints-1) * 3; % each column = 3s segment
%
% plot heatmap
figure('Position',[100 100 1000 600]);
t = tiledlayout(8,10,'TileSpacing','compact','Padding','compact');

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
imagesc(time_axis_sec, 1:size(CNN_map,1), CNN_map);
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
bad_chan_idx = find(badchannels == 1); % row indices of bad channels
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