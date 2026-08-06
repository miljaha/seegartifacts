%%
load("/projects3/EPIHFO/EPIHFO/CNN results/Pat76_focal.mat")
events = readtable("/projects3/EPIHFO/EPIHFO/Pat76/Pat76_focal_artefacts.xlsx");
channels = readtable("/projects3/EPIHFO/EPIHFO/Pat76/full_night_detection_rates_pat76.xls", Sheet="files combined",Range="A10:C168");

% ================================================================
%  Extract Focal artefact onset/offset times (relative to recording
%  start) and match derivation channel pairs to channel numbers.
%
%  Assumes you already have two tables in your workspace:
%     events    - variables: Type, Text, Position, Duration, Derivation
%     channels  - variables: ChannelNumber, Label, Bad
%
% ================================================================

% ---- Recording start time = first row's Position ----
startSec = local_posToSec(events.Position{1});

% ---- Keep only 'Focal artefact' rows ----
isFocal = strcmp(events.Type, 'Focal artefact');
focal   = events(isFocal, :);
nF      = height(focal);

StartTime_s  = zeros(nF,1);
EndTime_s    = zeros(nF,1);
Duration_s   = zeros(nF,1);
Ch1          = strings(nF,1);
Ch2          = strings(nF,1);
ChannelLabel = strings(nF,1);
ChannelNum   = nan(nF,1);

for i = 1:nF
    % ---- timing, day-aware (handles d1 -> d2 midnight rollover) ----
    StartTime_s(i) = local_posToSec(focal.Position{i}) - startSec;
    Duration_s(i)  = str2double(regexp(focal.Duration{i}, '[\d.]+', 'match', 'once'));
    EndTime_s(i)   = StartTime_s(i) + Duration_s(i);

    % ---- channel matching ----
    toks = strsplit(strtrim(focal.Derivation{i}));
    if numel(toks) == 2
        Ch1(i) = toks{1};
        Ch2(i) = toks{2};

        % channels table uses a dash between the two contacts -> add it
        combinedLabel = strcat(toks{1}, '-', toks{2});
        idx = find(strcmp(channels.Label, combinedLabel));

        % fallback: try the reversed order too, just in case
        if isempty(idx)
            combinedLabel = strcat(toks{2}, '-', toks{1});
            idx = find(strcmp(channels.Label, combinedLabel));
        end

        ChannelLabel(i) = combinedLabel;
        if ~isempty(idx)
            ChannelNum(i) = channels.ChannelNumber(idx(1));
        end
    end
end

focal_artefacts = table(StartTime_s, EndTime_s, Duration_s, Ch1, Ch2, ChannelLabel, ChannelNum);


%% ---- Keep 'Artefact' rows (applies to ALL channels, no derivation) ----
isAllChanArtefact = strcmp(events.Type, 'Artefact_PN');
allChan           = events(isAllChanArtefact, :);
nA                = height(allChan);
 
StartTime_s_all = zeros(nA,1);
EndTime_s_all   = zeros(nA,1);
Duration_s_all  = zeros(nA,1);
 
for i = 1:nA
    StartTime_s_all(i) = local_posToSec(allChan.Position{i}) - startSec;
    Duration_s_all(i)  = str2double(regexp(allChan.Duration{i}, '[\d.]+', 'match', 'once'));
    EndTime_s_all(i)   = StartTime_s_all(i) + Duration_s_all(i);
end
 
general_artefacts = table(StartTime_s_all, EndTime_s_all, Duration_s_all);

CNN_map = CNNresults.CNN_map;
%% ================================================================
%  Plot CNN_map (as usual) and overlay Focal artefact patches
%
%  Requires in workspace:
%     CNN_map  - channels x segments matrix (your usual CNN output)
%     results  - table from focal_artefact_extraction.m
%                (needs StartTime_s, EndTime_s, ChannelNum columns)
% ================================================================

CNN_map = rand(158,3.8*60*60/3);
segLen = 3; % seconds per CNN_map segment - change if different
 
figure;
imagesc(CNN_map);            % your usual CNN_map plot
colormap(flipud(gray));            % swap for whatever colormap you normally use
colorbar;
xlabel('Segment (3 s each)');
ylabel('Channel');
title('CNN map with Focal artefact overlays');
hold on;
 
for i = 1:height(focal_artefacts)
    ch = focal_artefacts.ChannelNum(i);
    if isnan(ch)
        continue % skip rows where the derivation couldn't be matched
    end
 
    % convert seconds -> segment units (fractional, for accurate placement)
    startSeg = focal_artefacts.StartTime_s(i) / segLen;
    endSeg   = focal_artefacts.EndTime_s(i)   / segLen;
 
    % optional: enforce a minimum visible width for very short artefacts
    minWidth = 0.05; % in segment units, purely visual
    if (endSeg - startSeg) < minWidth
        endSeg = startSeg + minWidth;
    end
 
    % patch spanning [startSeg, endSeg] on the row for this channel
    x = [startSeg, endSeg, endSeg, startSeg];
    y = [ch-0.5,   ch-0.5, ch+0.5, ch+0.5];
 
    h1 = patch(x, y, 'r', 'FaceAlpha', 0.4, 'EdgeColor', 'r', 'LineWidth', 1);
end
 
% ---- Overlay all-channel 'Artefact' markings (full height) ----
%  Requires: results_allChannels (from focal_artefact_extraction.m)
nChan = size(CNN_map, 1);
 
for i = 1:height(general_artefacts)
    startSeg = general_artefacts.StartTime_s_all(i) / segLen;
    endSeg   = general_artefacts.EndTime_s_all(i)   / segLen;
 
    if (endSeg - startSeg) < minWidth
        endSeg = startSeg + minWidth;
    end
 
    x = [startSeg, endSeg, endSeg, startSeg];
    y = [0.5, 0.5, nChan+0.5, nChan+0.5]; % spans every channel row
 
    h2 = patch(x, y, 'y', 'FaceAlpha', 0.25, 'EdgeColor', 'y', 'LineWidth', 1);
end
legend([h1,h2],"Focal artefact","General artefact")
hold off;

% ================================================================
%  Local function: convert 'dN HH:MM:SS.sss' -> seconds, day-aware
%  (d1 = day 1, d2 = day 2 i.e. crossed midnight, etc.)
% ================================================================
function sec = local_posToSec(str)
    tok = regexp(str, 'd(\d+)\s+(\d+):(\d+):(\d+\.?\d*)', 'tokens', 'once');
    day = str2double(tok{1});
    h   = str2double(tok{2});
    m   = str2double(tok{3});
    s   = str2double(tok{4});
    sec = (day-1)*86400 + h*3600 + m*60 + s;
end

