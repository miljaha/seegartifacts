%% Detection of Ripples in SEEG Data
% Mohammad Al-Sa'd, 2026
% This code is re-written from the MATLAB function authored by
% Nicolas von Ellenrieder - nicolas.von.ellenrieder@mcgill.ca May 2019.
% This code version by M. Al-Sa'd is a simple re-writting and reorganization
% intended for clarity and understanding. The code link to the equations in
% the original publications can be found in the comments
%
function [Ripples, Events] = ripple_detector(Data, fs)
%% Parameters
WindowLength   = 5;      % Background moving window length [seconds]
RMS_Threshold  = 3;      % Threshold (RMS of background times this value)
MinSeparation  = 0.008;  % Minimum separation between FRs [seconds]
num_hfo_cycles = 4;      % HFO minimum number of cycles

%% Initialization
num_of_events = size(Data,1);            % Number of samples
num_Channels  = size(Data,2);            % Number of channels
WindowLength  = round(WindowLength*fs);  % Background moving window length in samples
MinSeparation = round(MinSeparation*fs); % Minimum separation between FRs in samples

%% General Bandpass Filtering via Parks-McClellan optimal equiripple FIR filter
BandpassOrder  = 200;                          % General bandpass filter order
Freq_band_edge = [0 65 80 500 515 fs/2].*2/fs; % Vector of frequency band edges
Amp_freq_edge  = [0 0 1 1 0 0];                % Amplitude for each frequency edge
Error_weight   = [10 1 1];                     % Error weight vector in dB
% Design the Parks-McClellan optimal equiripple FIR filter
BandpassFilter = firpm(BandpassOrder, Freq_band_edge, Amp_freq_edge, Error_weight);
% Apply the filter to a padded signal becasue the output will have a BandpassOrder/2 shift in response
BanspassSignal = filter(BandpassFilter, 1, [Data; zeros(BandpassOrder/2,num_Channels)]);
% Remove the delay in the filter response
BanspassSignal(1:BandpassOrder/2,:) = [];
clear Data;

%% Design the Parks-McClellan optimal equiripple narrowband bandpass FIR filters
NarrowbandOrder = 508;                          % Narrowband bandpass filter order
Freq_band_range = [80 115 150 185 220 250];     % Passbands of the narrowband fitlers
Amp_freq_edge   = [0 0 1 1 0 0];                % Amplitude for each frequency edge
Error_weight    = [10 1 1];                     % Error weight vector in dB
NarrowBandFilters = zeros(length(Freq_band_range)-1,NarrowbandOrder+1);
for i = 1:length(Freq_band_range)-1
    % Vector of frequency band edges
    Freq_band_edge = [0, Freq_band_range(i)-7 Freq_band_range(i)+3 Freq_band_range(i+1)-3 Freq_band_range(i+1)+7 fs/2]*2/fs;
    % Design the Parks-McClellan optimal equiripple FIR filter
    NarrowBandFilters(i,:) = firpm(NarrowbandOrder,Freq_band_edge,Amp_freq_edge,Error_weight);
end

%% Minimum length of the Events, i.e. the filter effective duration plus num_hfo_cycles cycles of the band central frequency.
% Check Eq.11 in "von Ellenrieder, Nicolás, et al. "Automatic detection of fast oscillations
% (40–200 Hz) in scalp EEG recordings." Clinical Neurophysiology 123.4 (2012): 670-680".
Central_freq = (Freq_band_range(1:end-1) + Freq_band_range(2:end))/2; % Central frequencies of each band
n2  = repmat((-NarrowbandOrder/2:NarrowbandOrder/2),length(Central_freq),1).^2;
num = sum(n2.*NarrowBandFilters.^2, 2);
den = sum(NarrowBandFilters.^2, 2);
MinimumLength = round(sqrt(num./den) + num_hfo_cycles.*fs./Central_freq');

%% HFO Detection
Offset = (NarrowbandOrder+BandpassOrder)/2;  % The combined filter delay in samples
Events = cell(1,length(Freq_band_range)-1);  % The detected events and their properties
if num_of_events < WindowLength + 1, WindowLength = num_of_events - 3; end % Fix if the signal duration is less than the window length
for k = 1:length(Freq_band_range)-1 % iterate across frequency bands
    %% Narrowband Bandpass Filtering
    % Apply the filter to a padded signal becasue the output will have a NarrowbandOrder/2 shift in response
    NarrowbandSignal = filter(NarrowBandFilters(k,:),1,[BanspassSignal; zeros(NarrowbandOrder/2,num_Channels)]);
    % Remove the delay in the filter response
    NarrowbandSignal(1:NarrowbandOrder/2,:) = [];

    %% Compute the RMS value of the Signal
    % Check Eq.12 in "von Ellenrieder, Nicolás, et al. "Automatic detection of fast oscillations
    % (40–200 Hz) in scalp EEG recordings." Clinical Neurophysiology 123.4 (2012): 670-680".
    CyclesHalfDuration = floor(fs*(num_hfo_cycles/2)/Central_freq(k)); % Half duration in samples
    % Moving average signal
    mov_avg_signal = filter(ones(1,2*CyclesHalfDuration+1)./(2*CyclesHalfDuration+1),1,NarrowbandSignal.^2);
    clear NarrowbandSignal;
    % The RMS signal
    RMSSignal = sqrt([mov_avg_signal; zeros(CyclesHalfDuration,num_Channels)]);
    % Remove the delay in the filter response
    RMSSignal(1:CyclesHalfDuration,:) = [];

    %% Compute the Moving Background Level
    % Check Eqs.14-15 in "von Ellenrieder, Nicolás, et al. "Automatic detection of fast oscillations
    % (40–200 Hz) in scalp EEG recordings." Clinical Neurophysiology 123.4 (2012): 670-680".
    MovingBackground = RMSSignal;
    IterativeBackgroundEstimator = RMSSignal;
    MovingBackground(1:WindowLength,:) = repmat(mean(RMSSignal(1:WindowLength,:)),WindowLength,1);
    for n = WindowLength+1:num_of_events
        % Eq. 14
        zk = RMSSignal(n-CyclesHalfDuration,:);
        bk = MovingBackground(n-CyclesHalfDuration,:);
        IterativeBackgroundEstimator(n,:) = min(zk,RMS_Threshold*bk);
        % Eq. 15
        MovingBackground(n,:) = MovingBackground(n-1,:) + ( IterativeBackgroundEstimator(n,:)-IterativeBackgroundEstimator(n-WindowLength,:) )/WindowLength;
    end

    %% Compute the Detection Indicator Signal
    % Check Eq.16 in "von Ellenrieder, Nicolás, et al. "Automatic detection of fast oscillations
    % (40–200 Hz) in scalp EEG recordings." Clinical Neurophysiology 123.4 (2012): 670-680".
    CandidateDetections = RMSSignal > RMS_Threshold*MovingBackground; % First detections
    % Find begining and end of detections (edges)
    CandidateDetections([1:Offset end-Offset:end],:) = false;
    % Detect events and their propeties
    [Isample,Ichannel] = find(xor(CandidateDetections(1:end-1,:),CandidateDetections(2:end,:)));
    EventStart         = Isample(1:2:end)+1;     % Event start time in samples
    EventEnd           = Isample(2:2:end);       % Event end time in samples
    EventLength        = EventEnd-EventStart+1;  % Event duration in samples
    DetectionChannel   = Ichannel(1:2:end);      % Event detection channel
    NumberOfEvents     = length(EventStart);     % Total number of detected events
    Values             = ones(NumberOfEvents,1);
    for jj = 1:NumberOfEvents
        ajj = RMSSignal(EventStart(jj):EventEnd(jj),DetectionChannel(jj));
        bjj = MovingBackground(EventStart(jj):EventEnd(jj),DetectionChannel(jj));
        Values(jj) = max(ajj./bjj);
    end
    % Concatenate all characteristics
    Events{k} = [DetectionChannel Central_freq(k)*ones(NumberOfEvents,1),EventStart EventLength, Values];
    % Keep only detections of enough length
    Events{k}(EventLength < MinimumLength(k),:) = [];
end
Events = cat(1,Events{:}); % Concatenate characteristics across bands

%% Detection Integration Across Frequency Bands (combine simultaneous detections at different frequency bands)
Ripples = cell(1,num_Channels);
for i = 1:num_Channels % iterature through channels
    EventsInChannel = Events(Events(:,1) == i,:); % extract events in channel i
    ChannelEvent = zeros(size(EventsInChannel));
    Counter = 0;
    while size(EventsInChannel,1) > 0
        num_of_events = size(EventsInChannel,1); % number of HFO events in channel i
        AllEvents = [EventsInChannel; ChannelEvent(1:Counter,:)]; % all events in channel i
        cond1 = (AllEvents(:,3) + AllEvents(:,4) + MinSeparation) > EventsInChannel(1,3);       % end + sep > start
        cond2 = AllEvents(:,3) < (EventsInChannel(1,3) + EventsInChannel(1,4) + MinSeparation); % start < end + sep
        IndexOfEvents = cond1 & cond2; % if true events overlap across frequencies
        OverlappingEvents = AllEvents(IndexOfEvents,:); % extract overlapping events
        EventsInChannel(IndexOfEvents(1:num_of_events),:) = [];
        ChannelEvent(IndexOfEvents(num_of_events+1:end),:) = [];
        Counter = Counter + 1 - nnz(IndexOfEvents(num_of_events+1:end));
        % events are represented as [channel, mean central frequency, start, duration, amplitude]
        ChannelEvent(Counter,:) = [OverlappingEvents(1,1),...
            mean(OverlappingEvents(:,2)) min(OverlappingEvents(:,3)),...
            max(OverlappingEvents(:,3) + OverlappingEvents(:,4)) - min(OverlappingEvents(:,3)),...
            max(OverlappingEvents(:,5))];
    end
    Ripples{i} = ChannelEvent(1:Counter,:); % Collect results from each channel
end
Ripples = cat(1,Ripples{:}); % Concatenate all characteristics
Events = sortrows(Events,1);
end