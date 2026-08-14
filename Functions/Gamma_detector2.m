%% Detection of gamma oscillaion in SEEG Data
% Milja Harju, 2025
% heavily inspired by https://github.com/Lab-Frauscher/Spike-Gamma/blob/main/compute_gamma.m

function GammaSpikes = Gamma_detector2(Data, IED_original ,fs, sample_window)
%% Parameters
threshold_factor = 2;
n_cycles_sustained = 3;
segment_length = 1; % how many seconds before and after onset is analyzed
%% 
n_IEDs = size(IED_original,1);

%% Adjust start / end times
mod_times = zeros(n_IEDs, 2); % [start, end]
% Scaling the samples with sample window because onset is in "original"
% whole record samples
onset = IED_original(:,3); % size: [n_IEDs, 1]
onset_shifted = onset - sample_window;
mod_times(:,1) = onset_shifted - segment_length*fs + 1;
mod_times(:,2) = onset_shifted + segment_length*fs + 1;

rel_onset = onset - mod_times(:,1); % Samples in segment
p1_list = rel_onset-sample_window + 1; % Start of IED
n2_list = rel_onset+IED_original(:, 4) - sample_window; % End of IED
% p1 & n2: Thomas et al., 2023, A Subpopulation of Spikes Predicts Successful Epilepsy Surgery Outcome
    
%% 30-100 Hz bandpass filtering the data
[b_gm, a_gm] = butter(4, [30 100] * 2/fs, 'bandpass'); % define gamma filter
signal = filtfilt(b_gm, a_gm, Data');

%% Define a filterbank 
filterbank = cwtfilterbank('SignalLength',2*fs,'SamplingFrequency',fs,'FrequencyLimits',[30 100],'VoicesPerOctave',40);

%% Create table for detections
GammaSpikes = zeros(size(IED_original,1), 4); % [channel, freq, start, duration]

%% Check each IED for gamma
for IED=1:n_IEDs
    %% Trim segment around IED
    chan = IED_original(IED, 1);
    segment = signal(chan, mod_times(IED,1):mod_times(IED,2)); % 2 second segment
    % Note: segment is sometimes 1 s long, sometimes 2 s, depends on source
    f_gamma = segment(1:end-1);

    % Compute Morse Wavelet on signal using filterbank
    [tf,tf_freqs]=wt(filterbank,f_gamma);
    gamma_baseline=abs(tf); % Power  
    
    %% Only consider ±0.5 s from IED (before p1 and after n2), delete outside that
    p1 = p1_list(IED);
    n2 = n2_list(IED);

    todelete = [1:floor(p1-fs/2-1) floor(p1):ceil(n2) ceil(n2+fs/2+1):size(gamma_baseline,2)];
    gamma_baseline(:,todelete) = []; % remove the extra segments

    %% Threshold for raised power
    % The threshold for gamma is defined as mean + threshold * sd.
    gamma_mean = mean(gamma_baseline,2); % across time
    sd_thresh = threshold_factor*std(gamma_baseline,[],2); 
    gamma_thresh = gamma_mean + sd_thresh;
    
    %% Identify the segments with gamma power > threshold
    gamma_2sd = gamma_baseline>gamma_thresh;
    gamma_2sd(:,[1:ceil(p1-fs/2) p1:end])=0;  % delete others than 0.5s before onset

    % Calculate the duration for each frequency in samples
    dur_thresh = n_cycles_sustained*ceil((1./tf_freqs)*fs);

    % Collect starts of each valid raised power
    starts = [];
    %% For each frequency identify significant gamma activity and store
    for i_freq =1:length(tf_freqs)
        % Find the locations at which the gamma activity was significant as
        % [start end] in samples
        pass = [0 gamma_2sd(i_freq,:) 0];
        segs = find(diff(pass));
        
        if ~isempty(segs)
            % if there is atleast one significant gamma activity, compute the
            % duration of the activity
            pairs = reshape(segs,2,length(segs)/2)';
            seglen = pairs(:,2) - pairs(:,1);
            %starts_freq = nan(size(pairs,1),1);
            % for each pair to [start end] of gamma acitivty, check whether the
            % activity is within 190 ms of P1 (Ren et al., 2015)
            % If the activity is within 190 ms and has a
            % duration of 3 cycles, record these values.
            for i_seg = 1:size(pairs,1)
                if (p1-pairs(i_seg,2) <= 0.19*fs) && seglen(i_seg) >= dur_thresh(i_freq)   
                        starts = [starts; pairs(i_seg,1)];
                end
            end
        end
    end

    if ~isempty(starts) % at least one valid gamma activity with this IED
        % Choose earliest startpoint as the start of the gamma activity
        % Duration: from earliest start to onset of IED (Ren et al 2015)
        GammaSpikes(IED,:) = [chan, 0, min(starts), p1 - min(starts)]; % [channel, freq, start, duration]
    end
   
    
end
%% Delete empty rows (IEDs not having gamma)
GammaSpikes = GammaSpikes(~all(GammaSpikes == 0, 2),:); 
end