function GammaSpikes = gamma_detector(Data, IED, fs, sample_window)
% Milja Harju and Mohammad Al-Sa'd, September 2025
%% Parameters
sd_alpha  = 2;           % threshold = mean + sd_alpha*std
n_cycles  = 3;           % minimum number of gamma cycles
segment_t = 1;           % buffer time in seconds (±seconds before/after the IED onset)

%% Adjust IED start / end times
segment_n   = segment_t*fs + 1;                              % number of buffer samples (before/after the IED onset)
IED_onset   = floor(IED(:,3) - sample_window + 1);           % start sample of the IED shifted with respect to its position in the original signal
IED_channel = IED(:,1);                                      % get the channel number of the detected IED
IED_dur     = floor(IED(:,4));                               % get the floating IED sample duration
IED_buffer  = IED_onset + [-1 1]*segment_n - [-1 1];         % compute the sample ranges for the buffer samples in segment_samples

%% 30-100 Hz bandpass filtering the data
[b_gm, a_gm] = butter(4, [30 100]*2/fs, 'bandpass');         % define gamma filter
signal = filtfilt(b_gm, a_gm, Data');                        % filter the input signal

%% Define a filterbank 
filterbank = cwtfilterbank('SignalLength',2*segment_t*fs + 1, ...
    'SamplingFrequency',fs,'FrequencyLimits',[30 100],'VoicesPerOctave',40); % filter bank for the CWT

%% Main Procedure
baseline_dur = 500/1000;                        % baseline time in seconds (±seconds before/after the IED duration)
proxmity_dur = 190/1000;                        % minimum proxmity to onset in seconds
GammaSpikes  = zeros(size(IED,1),4);            % [channel, freq, start, duration]
for i = 1:size(IED,1)                           % iterate through all the detected IEDs
    %%% Step 1: Extract IED segment
    segment = signal(IED_channel(i),IED_buffer(i,1):IED_buffer(i,2)); % segment of duration 2*segment_dur seconds
    %%% Step 2: Compute its time-frequency representation
    [gamma_tf, tf_freqs] = wt(filterbank, segment);                   % compute Morse Wavelet on signal using filterbank
    gamma_tf   = abs(gamma_tf);                                       % time-frequency representation of gamma activity
    dur_thresh = n_cycles*ceil(fs./tf_freqs);                         % calculate the minimum number of gamma samples for each frequency
    %%% Step 3: Trim the time-frequency representation
    gamma_baseline = gamma_tf;
    seg1 = 1:(segment_n-baseline_dur*fs-2);                           % delete the segment begining to get baseline_dur before the IED onset
    seg2 = segment_n:(segment_n+IED_dur);                             % delete the IED duration
    seg3 = (segment_n+IED_dur+baseline_dur*fs+1):2*segment_t*fs+1;    % delete the segment ending to get baseline_dur after the IED duration
    gamma_baseline(:,[seg1 seg2 seg3]) = [];                          % only consider ±baseline_dur from the IED duration
    %%% Step 4: Threshold the trimmed time-frequency representation
    gamma_mean   = mean(gamma_baseline,2);                            % temporal average
    sd_thresh    = std(gamma_baseline,[],2);                          % temporal standard deviation
    gamma_thresh = gamma_mean + sd_alpha*sd_thresh;                   % threshold for each frequency bin
    gamma_2sd    = gamma_tf > gamma_thresh;                           % threshold the gamma time-frequency representation
    gamma_2sd(:,[seg1 segment_n:end]) = 0;                            % consider the gamma increase for baseline_dur seconds before the IED onset
    %%% Step 5: Find the frequency and duration of significant gamma activity
    gamma_padded = [zeros(size(gamma_2sd,1),1), ...
                   gamma_2sd, zeros(size(gamma_2sd,1),1)];            % pad gamma_2sd with zeros at the start/end
    starts = find(diff(gamma_padded, 1, 2) == 1);                     % find the start of any significant activity
    ends   = find(diff(gamma_padded, 1, 2) == -1);                    % find the end of any significant activity
    [freq_s, t_s] = ind2sub(size(gamma_2sd), starts);                 % convert start linear indices to subscripts
    [freq_e, t_e] = ind2sub(size(gamma_2sd), ends);                   % convert end linear indices to subscripts
    [ff,Is] = sort(freq_s); tts = t_s(Is);                            % sort the start times according to frequency
    [~, Ie] = sort(freq_e); tte = t_e(Ie);                            % sort the end times according to frequency    
    durations = tte - tts;                                            % compute durations of all significant activities
    dur_thresh_seg = dur_thresh(ff);                                  % get duration thresholds per segment
    %%% Step 6: Check effective duration and proximity to the IED onset
    cond1 = durations >= dur_thresh_seg;                              % check if activity lasts more than the minimum number of gamma samples for each frequency
    cond2 = (segment_n - tte) <= proxmity_dur*fs;                     % check if activity is close to the IED onset
    valid = cond1 & cond2;                                            % compute the condition for valid gamma activity
    if ~isempty(tts(valid))                                           % if we have any detections
        earliest = min(tts(valid));                                   % get the activity overall start
        seg_st   = earliest + IED_buffer(i,1) - 1;                    % shift the activity start to match the input signal
        seg_dur  = segment_n - earliest;                              % get the activity complete duration
        seg_freq = mean(tf_freqs(ff(valid)));                         % get the activity average frequency
        seg_chn  = IED_channel(i);                                    % get the activity channel index
        GammaSpikes(i,:) = [seg_chn, seg_freq, seg_st, seg_dur];      % collect results in GammaSpikes
    else
        GammaSpikes(i,:) = nan(1,4);                                  % insert nans if we have no gamma detections
    end
end
GammaSpikes = GammaSpikes(~any(isnan(GammaSpikes),2),:);              % remove all nan entries from output
end