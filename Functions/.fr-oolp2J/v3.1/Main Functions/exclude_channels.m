function [exclude_mask, bipolar_labels, include_channel_idx, exclude_channel_idx] = exclude_channels(subj_num, label)
[~, bipo_inds, ~] = bipolar_montage_indices(label); % get montage indices
bipolar_labels = lower(string([char(label{bipo_inds(:,1)}) ...
    repelem('-',length(bipo_inds),1) char(label{bipo_inds(:,2)})]));   % convert unipolar labels to bipolar
bipolar_labels = erase(bipolar_labels,' ');                            % remove any empty spaces if exists
bad_chans = predefined_badchannels(subj_num);                          % get predefined bad channels
ch_idx = 1:size(bipolar_labels,1);                                     % initialize the channel array
exclude_mask = ismember(bipolar_labels, lower(bad_chans));             % check what channels needs to be excluded
include_channel_idx = ch_idx(~exclude_mask);                           % check what channels needs to be included
exclude_channel_idx = ch_idx(exclude_mask);                            % check what channels needs to be excluded
fprintf("%d bad channels were found\n",sum(sum(exclude_mask)));        % show how many bad channels detected
end