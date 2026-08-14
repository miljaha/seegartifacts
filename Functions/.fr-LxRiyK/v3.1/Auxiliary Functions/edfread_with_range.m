function y = edfread_with_range(edf_filename, sample_range, last_sample)
% Mohammad Al-Sa'd, 2026
edfhdr = MemReadEDF(edf_filename);                     % load edf header
fs = edfhdr.SamplingRate(1);                           % get the sampling rate
R = edfhdr.NumSamples(1);                              % number of samples per record
I1 = floor((sample_range(1) - 1)/R)*R + 1;             % first record containing sample_range(1)
I2 = floor((sample_range(2) - 1)/R)*R + 1;             % first record containing sample_range(2)
time_range = [(I1-1)/fs, (I2+R-1)/fs];                 % convert to edf time range
[~, x] = MemReadEDF(edf_filename, 'time', time_range); % load the required edf records
st = sample_range(1) - I1 + 1;                         % trimming indices (inclusive logic)
fi = sample_range(2) - I1;                             % trimming indices (inclusive logic)
fi = fi + (sample_range(2) == last_sample);            % check if this was the last sample
y = x(st:fi,:);                                        % trim the loaded edf data 
end