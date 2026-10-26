function [signal_samples,info] = get_gui_samples(CNN_cell, data_original, data_hfb, bipolar_labels, bad_chan_idx, maxpick, maxchan, include_bad)
fs = 2048;
badchans = zeros(size(CNN_cell,1),1);
badchans(bad_chan_idx) = 1;
% sort the segments based on their CNN artifact score
[sorted, idx] = sort(CNN_cell(:), 'descend');
[r, c] = ind2sub(size(CNN_cell), idx);
rowCount = zeros(size(CNN_cell,1), 1);              % how many picked per channel
keep = false(numel(idx), 1);
nPicked = 0;

% pick samples, max maxchan per channel
for k = 1:numel(idx)
    if ~include_bad && any(ismember(r(k), bad_chan_idx)) % skip ones in bad channels
        continue;
    end
    if rowCount(r(k)) < maxchan
        keep(k) = true;
        rowCount(r(k)) = rowCount(r(k)) + 1;
        nPicked = nPicked + 1;
        if nPicked == maxpick, break; end
    end
end

% save info, raw signal and filtered signal
picked_samples = [sorted(keep), r(keep), c(keep), badchans(r(keep))];
signal_samples = zeros(2,3*fs,maxpick);
info = cell(maxpick,4);
for i = 1:size(picked_samples,1)
    score = picked_samples(i,1);
    channel = picked_samples(i,2);
    bad = picked_samples(i,4);
    segstart = (picked_samples(i,3)-1)*3*fs +1;
    segend = picked_samples(i,3)*3*fs;
    signal_samples(1,:,i) = data_original(segstart:segend, channel)';
    signal_samples(2,:,i) = data_hfb(segstart:segend, channel)';
    info(i,:) = {score,channel,bipolar_labels(channel),bad};
end