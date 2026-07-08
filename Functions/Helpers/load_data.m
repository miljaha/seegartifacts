function [data, fs, start_datetime] = load_data(data_dir, subj_num)

    % Find, list, and sort the EDF files of the selected subject
    datetime_format = 'dd-MMMM-yyyy HH:mm:ss.SSSSSSSSS';
    [EDFhdr, data] = MemReadEDF(data_dir, 'annotations'); % load data and annotations
    fs = EDFhdr.SamplingRate(1); % get the edf file sampling rate
    dt_str = strrep(EDFhdr.StartDate,".","-") + " " + strrep(EDFhdr.StartTime,".",":") + ".0"; % start datetime of the edf file in string format
    start_datetime = datetime(dt_str,"InputFormat",'dd-MM-yy HH:mm:ss.S','Format',datetime_format); 
    [N, M] = size(data);         % number of samples and channels
    
    label  = string(erase(EDFhdr.ChanLabel(1:M)',"POL ")); % remove "POL " from the channel labels
    fprintf('File %s is loaded successfully...\n', data_dir);
    [~, bipo_inds, ~] = bipolar_montage_indices(label); % get montage indices

    bipolar_labels = lower(string([char(label{bipo_inds(:,1)}) ...
        repelem('-',length(bipo_inds),1) char(label{bipo_inds(:,2)})])); % Cover unipolar labels to bipolar
    bipolar_labels = erase(bipolar_labels,' ');                          % Remove any empty spaces if exists
    data = uni2bi_montage(data', label); % Convert the data to the bipolar montage (MA updated) 
    
    bad_chans = predefined_badchannels(subj_num);
    exclude_channel_idx = ismember(bipolar_labels, lower(bad_chans));
    data.x_bip = data.x_bip(~exclude_channel_idx,:);
    data.lab_bip = data.lab_bip(~exclude_channel_idx,:);
    
end