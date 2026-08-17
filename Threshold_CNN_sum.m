subj_num = 22; % subject number
data_dir = "/projects3/EPIHFO/EPIHFO/CNN results/Pat" + string(subj_num)+"retnew";
fs = 2048;
windowSize = 3*fs;

load(data_dir);

CNN_probabilities = CNNresults.CNN_map(:,:,1);
artefact_samples = CNNresults.artefact_samples;

total_per_t = sum(CNN_probabilities,1);

nTimepoints = size(CNN_probabilities,2);

% convert shifted artefact samples into segment/timepoint units (matching CNN_probabilities columns)
artefact_segments = artefact_samples / windowSize; % fractional segment index, x-axis units
true_artefacts = zeros(1, nTimepoints);

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

% testaus eri thresholdeilla
n_ch = 99;
diffs = zeros(1,n_ch);
limit = 0:0.3:99;

for l = 1:size(limit,2)
    lim = limit(l);
    above_limit = total_per_t > lim;
    
    TP = sum(above_limit == 1 & true_artefacts == 1);
    FP = sum(above_limit == 1 & true_artefacts == 0);
    FN = sum(above_limit == 0 & true_artefacts == 1);
    TN = sum(above_limit == 0 & true_artefacts == 0);
    
    precision(l) = TP / (TP + FP + eps);
    recall(l)    = TP / (TP + FN + eps);
    F1(l)        = 2 * precision(l) * recall(l) / (precision(l) + recall(l) + eps);
end

[best_F1, best_idx] = max(F1);
best_threshold = limit(best_idx);
