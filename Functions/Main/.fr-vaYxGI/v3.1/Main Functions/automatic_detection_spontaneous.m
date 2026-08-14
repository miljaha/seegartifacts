% Copyright (c) 2026 Mohammad Al-Sa'd & Päivi Nevalainen
%
% Permission is hereby granted, free of charge, to any person obtaining a
% copy of this software and associated documentation files (the "Software"),
% to deal in the Software without restriction, including without limitation
% the rights to use, copy, modify, merge, publish, distribute, sublicense,
% and/or sell copies of the Software, and to permit persons to whom the
% Software is furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included
% in all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
% OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
% THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
% DEALINGS IN THE SOFTWARE.
%
% Email: ext-mohammad.al-sad@hus.fi, paivi.nevalainen@hus.fi
%
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
%        HUS Automatic Detection Toolbox for Spontaneous SEEG v3.1         
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
% <INPUTs>
% subj_num              : subject number, e.g, 18.
% data_dir              : directory where the edf data files exist.
% data_files            : selected set of edf files to be used, e.g.,
%                         {"EEG_204-export.edf","EEG_205-export.edf"} or
%                         {""} to automatically select all available files.
% user_datetime_range   : selected start and end datetime, e.g.,
%                         {"27-Nov-2019 09:20:00","3-5-2021 13:5:00"}
%                         or {"",""} to automatically select suitable range.
% user_segment_duration : selected segmentation duration in seconds, e.g.,
%                         5*60, "100", or [] to de-activate segmentation.
% user_measure          : selected detection measure, e.g., "R", ["FR","R"],
%                         or ["r","fr","s","sr","sfr","gs"] where "R" is 
%                         for Ripples, "FR" is for Fast-Ripples, "S" is for
%                         Spikes, "SR" is for Spike-Ripples, "SFR" is for 
%                         Spike-Fast-Ripples, and "GS" is for Gamma-Spikes.
%
% <OUTPUTs>
% out                   : program status in text.
%
% <Notes>
% This toolbox version supports:
% (1)  different sampling rates in each edf file.
% (2)  exact, non-exact, and empty datetime range selection.
% (3)  full-precision datetime computations.
% (4)  exact, non-exact, and empty data files selection.
% (5)  logging the screen outputs for remote support.
% (6)  finds and skips invalid annotations instances.
% (7)  custom edf reader with arbitrary time ranges.
% (8)  user-defined signal segmentation to reduce computational load.
% (9)  user-defined multi-measure selection and processing.
% (10) saving detailed detection results in HDF5 format (currently disabled
%      becasue it is slow) and MAT format.
% (11) saving summary results in multiple Excel files.
% (12) optimized loading and processing of data.
% (13) various input datetime formats.
% (14) automatic annotation extraction from internal files (.edf) and
%      external files (.xlsx, .xls, .csv, or .txt).
% (15) supports both serial and parallel operations.
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%

function out = automatic_detection_spontaneous(subj_num, data_dir, data_files, user_datetime_range, user_segment_duration, user_measure)
%% Start the program
diary off; % close any open log files
diary_file_str = "diary_pat" + string(subj_num) + ".txt"; % initialize the diary filename
if exist(diary_file_str, 'file') > 0 % check if an older log file exists and delete it
    delete(diary_file_str);
end
diary(diary_file_str); % log the screen outputs in a diary
fprintf(2,'======================================================================================\n');
fprintf(2,'=                                    Program Start                                   =\n');
fprintf(2,'======================================================================================\n');
fprintf("Processing data from subject number %d\n", subj_num);
out = "The program has started";

%% Checking data and file directories
fprintf(2,'\n======                    Checking data and file directories                    ======\n');
[data_dir, edf_filename] = check_dir(data_dir, data_files);

%% Checking the input datetime range
fprintf(2,'\n======                        Checking the datetime range                       ======\n');
user_datetime_range = check_datetime(user_datetime_range);

%% Find, list, and sort the edf files of the selected subject
fprintf(2,'\n======                      The list of available edf files                     ======\n');
[data_length, sampling_rate, start_datetime, end_datetime, user_datetime_range, edf_filename] = check_files(data_dir, edf_filename, user_datetime_range);

%% Process the edf files based on the user-defined datetime range
fprintf(2,'\n======       The processed list of edf files based on the datetime range        ======\n');
[edf_filename, start_datetime, end_datetime, sampling_rate, sample_window, num_edf_files] = exclude_files(edf_filename, user_datetime_range, start_datetime, end_datetime, data_length, sampling_rate);

%% Checking the signal segmentation mode
fprintf(2,'======                      Checking the segmentation mode                      ======\n');
segment_sample_window = check_segmentation(edf_filename, user_segment_duration, sample_window, sampling_rate);

%% Checking the selected detection measure
fprintf(2,'\n======                 Checking the selected detection measures                 ======\n');
short_list_of_measures = ["r","fr","s","sr","sfr","gs"];
complete_list_of_measures = ["Ripples","Fast-Ripples","Spikes","Spike-Ripples",...
    "Spike-Fast-Ripples","Gamma-Spikes"];
user_measure = check_measure(user_measure, short_list_of_measures, complete_list_of_measures);

%% Intialize variables
seizure_time_overflow_start = 0;          % seizure time overflows starts to the current file from other files
seizure_time_overflow_end = 0;            % seizure time overflows ends to the current file from other files
all_labels      = cell(1,num_edf_files);  % cell array holding the good channel labels from all recordings
all_bad_labels  = cell(1,num_edf_files);  % cell array holding the bad channel labels from all recordings
all_info        = cell(1,num_edf_files);  % cell array holding the recordings info
all_rates       = cell(1,num_edf_files);  % cell array holding the rates from all recordings

%% Main Script applied to each subject's record separately
fprintf(2,'--------------------------------------------------------------------------------------\n');
for file_number = 1:num_edf_files % iterate through the subject's included files/recordings
    % Logic flages to check if accessing a prior file is needed
    handle_file    = true;
    looped_already = false;
    while handle_file
        %% Checking data and annotations from the edf file
        idx = file_number - 1.*looped_already; % determine the index of the file to be handled
        file_name = edf_filename(idx);  % get the edf filename
        fprintf(2,'======        Checking data and annotations in file "%s"        ======\n', file_name);
        [fs, N, label, events] = check_data(data_dir, file_name);

        %% Extracting bad channels from the edf file
        fprintf(2,'\n======           Extracting bad channels in file "%s"           ======\n', file_name);
        [exclude_channel_mask, bipolar_labels, include_channel_idx, exclude_channel_idx] = exclude_channels(subj_num, label);

        %% Extracting artefact and seizure segments from annotations
        fprintf(2,'\n======         Extracting artefact and seizure segments from annotations        ======\n');
        artefact_samples = extract_artefact_locations(events, N, fs); % search for the artefact samples in the file
        % search for seziure samples in the file and gather buffered seizure timestamps from events
        [seizure_samples, overflow_start, overflow_end] = extract_seizure_locations(events, N, fs, ...
            seizure_time_overflow_start, seizure_time_overflow_end, looped_already);
        % combine artefact and seizure intervals
        both_samples = merge_intervals(seizure_samples, artefact_samples);
        % save seizure time overflows (overflows at start -> Goes to PREVIOUS file)
        seizure_time_overflow_start = overflow_start;
        % Only saves the end overflow if not rehandling prior file (overflows at end -> Goes to NEXT file)
        if ~looped_already, seizure_time_overflow_end = overflow_end; end

        %% Applying the automatic detection pipeline
        fprintf(2,'\n======                 Applying the automatic detection pipeline                ======\n');        
        R_original = []; FR_original = []; IED_original = []; GS_original = [];
        num_segments = size(segment_sample_window{idx},2);
        for seg_num = 1:num_segments
            if num_segments == 1
                fprintf('--- Loading the entire requested duration ---\n');
            else
                fprintf('--- Loading segment %d/%d from the edf file ---\n', seg_num, num_segments);
            end
            data = edfread_with_range(fullfile(data_dir, file_name), segment_sample_window{idx}(:,seg_num), segment_sample_window{idx}(2,end));

            disp('--- Preprocessing ---');
            data = uni2bi_montage(data', label);                  % convert the data to the bipolar montage
            data.x_bip = data.x_bip(~exclude_channel_mask,:)';    % exclude bad channels from data

            disp('--- Automatic detection ---');
            if any(ismember(["r","sr"], user_measure)) % condition to calculate ripples
                disp("Ripples");
                temp = ripple_detector(data.x_bip, fs); % detection
                temp(:,3) = temp(:,3) + segment_sample_window{idx}(1,seg_num) - 1;  % shift start time
                R_original = cat(1, R_original, temp); % concatenate results from each segment
            end
            if any(ismember(["fr","sfr"], user_measure)) % condition to calculate fast-ripples
                disp("Fast-Ripples");                
                temp = fast_ripple_detector(data.x_bip, fs); % detection
                temp(:,3) = temp(:,3) + segment_sample_window{idx}(1,seg_num) - 1;  % shift start time
                FR_original = cat(1, FR_original, temp); % concatenate results from each segment
            end
            if any(ismember(["s","sr","sfr","gs"], user_measure)) % condition to calculate spikes
                disp("Spikes");                
                settings = '-h 50 -dec 200 -b 8';
                parallel_flag = false;
                Spikes = spike_detector_hilbert_v23(data.x_bip, fs, settings, parallel_flag); % detection
                Spikes.pos = Spikes.pos(:).*fs + segment_sample_window{idx}(1,seg_num);   % start in samples (rounding is removed on purpose)
                Spikes.dur = Spikes.dur(:).*fs;   % duration in samples (rounding is removed on purpose)
                temp_spikes = [Spikes.chan, nan(size(Spikes.chan)), Spikes.pos, Spikes.dur, nan(size(Spikes.chan))]; % gather all results (similar format to R and FR)
                if isempty(temp_spikes) % if no spikes were detected
                    temp_spikes = zeros(0,5);
                end
                IED_original = cat(1, IED_original, temp_spikes); % concatenate results from each segment
            end
            if any(ismember("gs", user_measure)) % condition to calculate gamma-spikes
                disp("Gamma-Spikes");                
                if ~isempty(temp_spikes) % if we have detected spikes
                    temp = gamma_detector(data.x_bip, temp_spikes, fs, segment_sample_window{idx}(1,seg_num)); % detection
                    temp(:,3) = temp(:,3) + segment_sample_window{idx}(1,seg_num) - 1;  % shift start time
                    dump = [temp, nan(size(temp(:,1)))];
                else % if no spikes were detected
                    dump = temp_spikes;
                end
                GS_original = cat(1, GS_original, dump); % concatenate results from each segment
            end
        end
        clear data;

        disp('--- Postprocessing ---');
        if any(ismember(["r","sr"], user_measure)) % condition to process ripples
            R_original(:,1) = include_channel_idx(R_original(:,1));  % fix the detected channel numbers
            % Remove R segments overlapping with artefact and/or seizure segments
            [R_artefacts_removed, R_seizures_removed, R_both_removed] = remove_overlap(R_original, artefact_samples, seizure_samples, both_samples, "Ripples");
        end
        if any(ismember(["fr","sfr"], user_measure)) % condition to process fast-ripples
            FR_original(:,1) = include_channel_idx(FR_original(:,1));  % fix the detected channel numbers
            % Remove FR segments overlapping with artefact and/or seizure segments
            [FR_artefacts_removed, FR_seizures_removed, FR_both_removed] = remove_overlap(FR_original, artefact_samples, seizure_samples, both_samples, "Fast-Ripples");
        end
        if any(ismember(["s","sr","sfr","gs"], user_measure)) % condition to process spikes
            IED_original(:,1) = include_channel_idx(IED_original(:,1));  % fix the detected channel numbers
            % Remove Spike segments overlapping with artefact and/or seizure segments
            [IED_artefacts_removed, IED_seizures_removed, IED_both_removed] = remove_overlap(IED_original, artefact_samples, seizure_samples, both_samples, "Spikes");
        end
        if any(ismember("sr", user_measure)) % condition to calculate spike-ripples
            N_buffer = 0.1*fs + 1;  % 100ms buffer
            SR_original          = find_spikes_in_ripples(R_original, IED_original, N_buffer);
            SR_artefacts_removed = find_spikes_in_ripples(R_artefacts_removed, IED_artefacts_removed, N_buffer);
            SR_seizures_removed  = find_spikes_in_ripples(R_seizures_removed, IED_seizures_removed, N_buffer);
            SR_both_removed      = find_spikes_in_ripples(R_both_removed, IED_both_removed, N_buffer);
            fprintf('The number of Spike-Ripples that were detected successfully\n');
            fprintf("Original: %d\n", size(SR_original,1));
            fprintf("Artefact-free: %d\n", size(SR_artefacts_removed,1));
            fprintf("Seizure-free: %d\n", size(SR_seizures_removed,1));
            fprintf("Artefact-seizure-free: %d\n", size(SR_both_removed,1));            
        end
        if any(ismember("sfr", user_measure)) % condition to calculate spike-fast-ripples
            N_buffer = 0.1*fs + 1;  % 100ms buffer
            SFR_original          = find_spikes_in_ripples(FR_original, IED_original, N_buffer);
            SFR_artefacts_removed = find_spikes_in_ripples(FR_artefacts_removed, IED_artefacts_removed, N_buffer);
            SFR_seizures_removed  = find_spikes_in_ripples(FR_seizures_removed, IED_seizures_removed, N_buffer);
            SFR_both_removed      = find_spikes_in_ripples(FR_both_removed, IED_both_removed, N_buffer);
            fprintf('The number of Spike-Fast-Ripples that were detected successfully\n');
            fprintf("Original: %d\n", size(SFR_original,1));
            fprintf("Artefact-free: %d\n", size(SFR_artefacts_removed,1));
            fprintf("Seizure-free: %d\n", size(SFR_seizures_removed,1));
            fprintf("Artefact-seizure-free: %d\n", size(SFR_both_removed,1));            
        end
        if any(ismember("gs", user_measure)) % condition to process gamma-spikes
            GS_original(:,1) = include_channel_idx(GS_original(:,1));  % fix the detected channel numbers            
            % Remove GS segments overlapping with artefact and/or seizure segments
            [GS_artefacts_removed, GS_seizures_removed, GS_both_removed] = remove_overlap(GS_original, artefact_samples, seizure_samples, both_samples, "Gamma-Spikes");
        end

        %% Rate computations
        fprintf(2,'\n======                             Rate computations                            ======\n');
        num_channels = size(bipolar_labels,1); % number of channels
        % Calculate signal duration
        duration_original = seconds(end_datetime(idx)-start_datetime(idx));
        duration_artefacts_removed = remaining_duration(sample_window(:,idx)', artefact_samples, duration_original, fs);
        duration_seizures_removed  = remaining_duration(sample_window(:,idx)', seizure_samples, duration_original, fs);
        duration_both_removed      = remaining_duration(sample_window(:,idx)', both_samples, duration_original, fs);
        % Calculate event rates (per minute) and percentages of occupancy for each channel
        if any(ismember("r", user_measure)) % condition to calculate ripple rates
            [R_appear_rate, R_occupancy_rate] = occurance_occupancy_rate(num_channels, exclude_channel_idx, fs, ...
                {R_original, R_artefacts_removed, R_seizures_removed, R_both_removed}, ...
                {duration_original, duration_artefacts_removed, duration_seizures_removed, duration_both_removed});
        end
        if any(ismember("fr", user_measure)) % condition to calculate fast-ripple rates
            [FR_appear_rate, FR_occupancy_rate] = occurance_occupancy_rate(num_channels, exclude_channel_idx, fs, ...
                {FR_original, FR_artefacts_removed, FR_seizures_removed, FR_both_removed}, ...
                {duration_original, duration_artefacts_removed, duration_seizures_removed, duration_both_removed});
        end
        if any(ismember("s", user_measure)) % condition to calculate spike rates
            [IED_appear_rate, IED_occupancy_rate] = occurance_occupancy_rate(num_channels, exclude_channel_idx, fs, ...
                {IED_original, IED_artefacts_removed, IED_seizures_removed, IED_both_removed}, ...
                {duration_original, duration_artefacts_removed, duration_seizures_removed, duration_both_removed});
        end
        if any(ismember("sr", user_measure)) % condition to calculate spike-ripple rates
            [SR_appear_rate, SR_occupancy_rate] = occurance_occupancy_rate(num_channels, exclude_channel_idx, fs, ...
                {SR_original, SR_artefacts_removed, SR_seizures_removed, SR_both_removed}, ...
                {duration_original, duration_artefacts_removed, duration_seizures_removed, duration_both_removed});
        end
        if any(ismember("sfr", user_measure)) % condition to calculate spike-fast-ripple rates
            [SFR_appear_rate, SFR_occupancy_rate] = occurance_occupancy_rate(num_channels, exclude_channel_idx, fs, ...
                {SFR_original, SFR_artefacts_removed, SFR_seizures_removed, SFR_both_removed}, ...
                {duration_original, duration_artefacts_removed, duration_seizures_removed, duration_both_removed});
        end
        if any(ismember("gs", user_measure)) % condition to calculate gamma-spike rates
            [GS_appear_rate, GS_occupancy_rate] = occurance_occupancy_rate(num_channels, exclude_channel_idx, fs, ...
                {GS_original, GS_artefacts_removed, GS_seizures_removed, GS_both_removed}, ...
                {duration_original, duration_artefacts_removed, duration_seizures_removed, duration_both_removed});
        end
        % Collect all computed rates
        all_appear_rate = [];
        all_occupancy_rate = [];
        for i = 1:length(user_measure) % iterate through the user-defined measures
            switch user_measure(i)
                case "r"
                    all_appear_rate = cat(2, all_appear_rate, R_appear_rate);
                    all_occupancy_rate = cat(2, all_occupancy_rate, R_occupancy_rate);
                case "fr"
                    all_appear_rate = cat(2, all_appear_rate, FR_appear_rate);
                    all_occupancy_rate = cat(2, all_occupancy_rate, FR_occupancy_rate);                    
                case "s"
                    all_appear_rate = cat(2, all_appear_rate, IED_appear_rate);
                    all_occupancy_rate = cat(2, all_occupancy_rate, IED_occupancy_rate);                    
                case "sr"
                    all_appear_rate = cat(2, all_appear_rate, SR_appear_rate);
                    all_occupancy_rate = cat(2, all_occupancy_rate, SR_occupancy_rate);                    
                case "sfr"
                    all_appear_rate = cat(2, all_appear_rate, SFR_appear_rate);
                    all_occupancy_rate = cat(2, all_occupancy_rate, SFR_occupancy_rate);                    
                case "gs"
                    all_appear_rate = cat(2, all_appear_rate, GS_appear_rate);
                    all_occupancy_rate = cat(2, all_occupancy_rate, GS_occupancy_rate);                    
            end
        end
        duration_original = duration_original/60;
        duration_artefacts_removed = duration_artefacts_removed/60;
        duration_seizures_removed = duration_seizures_removed/60;
        duration_both_removed = duration_both_removed/60;
        disp("Total duration in minutes without anything removed: " + string(duration_original));
        disp("Total duration in minutes with artefacts removed: " + string(duration_artefacts_removed));
        disp("Total duration in minutes with seizures removed: " + string(duration_seizures_removed));
        disp("Total duration in minutes with both artefacts and seizures removed: " + string(duration_both_removed));

        %% Export detailed detections to MAT and HDF5 formats
        fprintf(2,'\n======               Save detections for file "%s"              ======\n', file_name);
        if ~exist(fullfile(data_dir,"Detection Results"),"dir"), mkdir(fullfile(data_dir,"Detection Results")); end
        detections_format = ["channel number","frequency or nan","start sample","duration in samples","amplitude or nan"];
        notes = "The IED start and sample durations are not rounded. This affects also SR and SFR detections";
        bipolar_channels = upper(bipolar_labels);
        sampling_rate = fs;
        bad_channels = upper(bipolar_labels(exclude_channel_mask));

        if any(ismember("r", user_measure)) % condition to save ripple detections
            matfile = fullfile(data_dir, "Detection Results", string(erase(file_name, ".edf")) + "_detections_r.mat");
            if idx == 1 && exist(matfile,'file') > 0, delete(matfile); end % check if an older file exists and delete it
            save(matfile,'duration_original','duration_artefacts_removed','duration_seizures_removed','duration_both_removed', ...
                'sampling_rate','detections_format','notes','bipolar_channels','bad_channels');
            save(matfile,'R_original','R_artefacts_removed','R_seizures_removed','R_both_removed', ...
                'R_appear_rate','R_occupancy_rate','-append'); % save data
            fprintf('File "%s" is saved successfully ...\n', string(erase(file_name, ".edf")) + "_detections_r.mat");
        end
        if any(ismember("fr", user_measure)) % condition to save fast-ripple detections
            matfile = fullfile(data_dir, "Detection Results", string(erase(file_name, ".edf")) + "_detections_fr.mat");
            if idx == 1 && exist(matfile,'file') > 0, delete(matfile); end % check if an older file exists and delete it
            save(matfile,'duration_original','duration_artefacts_removed','duration_seizures_removed','duration_both_removed', ...
                'sampling_rate','detections_format','notes','bipolar_channels','bad_channels');
            save(matfile,'FR_original','FR_artefacts_removed','FR_seizures_removed','FR_both_removed', ...
                'FR_appear_rate','FR_occupancy_rate','-append'); % save data
            fprintf('File "%s" is saved successfully ...\n', string(erase(file_name, ".edf")) + "_detections_fr.mat");
        end
        if any(ismember("s", user_measure)) % condition to save spike detections
            matfile = fullfile(data_dir, "Detection Results", string(erase(file_name, ".edf")) + "_detections_s.mat");
            if idx == 1 && exist(matfile,'file') > 0, delete(matfile); end % check if an older file exists and delete it
            save(matfile,'duration_original','duration_artefacts_removed','duration_seizures_removed','duration_both_removed', ...
                'sampling_rate','detections_format','notes','bipolar_channels','bad_channels');
            save(matfile,'IED_original','IED_artefacts_removed','IED_seizures_removed','IED_both_removed', ...
                'IED_appear_rate','IED_occupancy_rate','-append'); % save data
            fprintf('File "%s" is saved successfully ...\n', string(erase(file_name, ".edf")) + "_detections_s.mat");
        end
        if any(ismember("sr", user_measure)) % condition to save spike-ripple detections
            matfile = fullfile(data_dir, "Detection Results", string(erase(file_name, ".edf")) + "_detections_sr.mat");
            if idx == 1 && exist(matfile,'file') > 0, delete(matfile); end % check if an older file exists and delete it
            save(matfile,'duration_original','duration_artefacts_removed','duration_seizures_removed','duration_both_removed', ...
                'sampling_rate','detections_format','notes','bipolar_channels','bad_channels');
            save(matfile,'SR_original','SR_artefacts_removed','SR_seizures_removed','SR_both_removed', ...
                'SR_appear_rate','SR_occupancy_rate','-append'); % save data
            fprintf('File "%s" is saved successfully ...\n', string(erase(file_name, ".edf")) + "_detections_sr.mat");
        end
        if any(ismember("sfr", user_measure)) % condition to save spike-fast-ripple detections
            matfile = fullfile(data_dir, "Detection Results", string(erase(file_name, ".edf")) + "_detections_sfr.mat");
            if idx == 1 && exist(matfile,'file') > 0, delete(matfile); end % check if an older file exists and delete it
            save(matfile,'duration_original','duration_artefacts_removed','duration_seizures_removed','duration_both_removed', ...
                'sampling_rate','detections_format','notes','bipolar_channels','bad_channels');
            save(matfile,'SFR_original','SFR_artefacts_removed','SFR_seizures_removed','SFR_both_removed', ...
                'SFR_appear_rate','SFR_occupancy_rate','-append'); % save data
            fprintf('File "%s" is saved successfully ...\n', string(erase(file_name, ".edf")) + "_detections_sfr.mat");
        end
        if any(ismember("gs", user_measure)) % condition to save gamma-spike detections
            matfile = fullfile(data_dir, "Detection Results", string(erase(file_name, ".edf")) + "_detections_gs.mat");
            if idx == 1 && exist(matfile,'file') > 0, delete(matfile); end % check if an older file exists and delete it
            save(matfile,'duration_original','duration_artefacts_removed','duration_seizures_removed','duration_both_removed', ...
                'sampling_rate','detections_format','notes','bipolar_channels','bad_channels');
            save(matfile,'GS_original','GS_artefacts_removed','GS_seizures_removed','GS_both_removed', ...
                'GS_appear_rate','GS_occupancy_rate','-append'); % save data
            fprintf('File "%s" is saved successfully ...\n', string(erase(file_name, ".edf")) + "_detections_gs.mat");
        end

        % hd5file = fullfile(data_dir, "Detection Results", string(erase(file_name, ".edf")) + "_detections_" + strjoin(user_measure,"_") + ".hd5");
        % if idx == 1 && exist(hd5file,'file') > 0, delete(hd5file); end % check if an older file exists and delete it
        % save_hdf5(hd5file, duration_original, duration_artefacts_removed, duration_seizures_removed, duration_both_removed);
        % save_hdf5(hd5file, sampling_rate, detections_format, notes, bipolar_channels, bad_channels);
        % if any(ismember("r", user_measure)) % condition to save ripple detections
        %     save_hdf5(hd5file, R_original, R_artefacts_removed, R_seizures_removed, R_both_removed); % save detections
        %     save_hdf5(hd5file, R_appear_rate, R_occupancy_rate); % save rates
        % end
        % if any(ismember("fr", user_measure)) % condition to save fast-ripple detections
        %     save_hdf5(hd5file, FR_original, FR_artefacts_removed, FR_seizures_removed, FR_both_removed); % save detections
        %     save_hdf5(hd5file, FR_appear_rate, FR_occupancy_rate); % save rates
        % end
        % if any(ismember("s", user_measure)) % condition to save spike detections
        %     save_hdf5(hd5file, IED_original, IED_artefacts_removed, IED_seizures_removed, IED_both_removed); % save detections
        %     save_hdf5(hd5file, IED_appear_rate, IED_occupancy_rate); % save rates
        % end
        % if any(ismember("sr", user_measure)) % condition to save spike-ripple detections
        %     save_hdf5(hd5file, SR_original, SR_artefacts_removed, SR_seizures_removed, SR_both_removed); % save detections
        %     save_hdf5(hd5file, SR_appear_rate, SR_occupancy_rate); % save rates
        % end
        % if any(ismember("sfr", user_measure)) % condition to save spike-fast-ripple detections
        %     save_hdf5(hd5file, SFR_original, SFR_artefacts_removed, SFR_seizures_removed, SFR_both_removed); % save detections
        %     save_hdf5(hd5file, SFR_appear_rate, SFR_occupancy_rate); % save rates
        % end
        % if any(ismember("gs", user_measure)) % condition to save gamma-spike detections
        %     save_hdf5(hd5file, GS_original, GS_artefacts_removed, GS_seizures_removed, GS_both_removed); % save detections
        %     save_hdf5(hd5file, GS_appear_rate, GS_occupancy_rate); % save rates
        % end
        % fprintf('File "%s" is saved successfully ...\n', string(erase(file_name, ".edf")) + "_detections_" + strjoin(user_measure,"_") + ".hd5");

        %% Export summary results to an Excel file
        fprintf(2,'\n======                Export rates for file "%s"                ======\n', file_name);
        info{1,1} = file_name;
        info{2,1} = string(start_datetime(idx));
        info{3,1} = string(end_datetime(idx));
        info{4,1} = duration_original;
        info{5,1} = duration_artefacts_removed;
        info{6,1} = duration_seizures_removed;
        info{7,1} = duration_both_removed;
        info{8,1} = "NaN" + " denotes bad channels";
        if ~exist(fullfile(data_dir,"Excel Results"),'dir'), mkdir(fullfile(data_dir,"Excel Results")); end
        for i = 1:length(user_measure)
            save_status = false;
            max_attempts = 10;
            attempt = 0;
            while ~save_status && attempt < max_attempts
                attempt = attempt + 1;
                try
                    excelfile = fullfile(data_dir,"Excel Results","detections_pat" + ...
                        subj_num + "_" + user_measure(i) + ".xlsx");
                    if idx == 1 && exist(excelfile,'file') > 0, delete(excelfile); end % check if an older file exists and delete it
                    sheet_name = string(erase(file_name,".edf"));
                    sheet_name = extractBetween(sheet_name, 1, min(strlength(sheet_name), 31)); % limit induced by excel sheet naming
                    st = 1 + (i-1)*4; fi = 4*i;
                    export_detections_to_excel(excelfile, sheet_name, info, ...
                        bipolar_channels, user_measure(i), all_appear_rate(:,st:fi), ...
                        all_occupancy_rate(:,st:fi), exclude_channel_idx);
                    save_status = true;
                catch ME
                    fprintf("Saving attempt %d/%d failed!\n", attempt, max_attempts);
                    fprintf("Reason: %s\n",ME.message);
                    fprintf("Re-Saving\n");
                    pause(1);
                end
            end
            if ~save_status
                error("File could not be saved after %d attempts!", max_attempts);
            end
        end
        % Save necessary information for combined file statistics
        all_labels{idx} = bipolar_channels;
        all_bad_labels{idx} = bad_channels;
        all_info{idx}   = info';
        all_rates{idx}  = [all_appear_rate, all_occupancy_rate];

        %% Check if need to redo previous file
        handle_file = false;
        if seizure_time_overflow_start > 0 && ~looped_already && idx > 1
            handle_file = true;
            looped_already = true;
            disp([newline '--- Seizure time overflows to previous file, reaccessing it ---' newline]);
        end
    end
end

%% Weighted mean of the subject's records (continue only with common channels)
% Find common labels across all files
common_all_labels = all_labels{1};
for i = 2:length(all_labels)
    common_all_labels = intersect(common_all_labels, all_labels{i}, 'stable');
end
common_bad_labels = all_bad_labels{1};
for i = 2:length(all_labels)
    common_bad_labels = union(common_bad_labels, all_bad_labels{i}, 'stable');
end
bad_idx = find(ismember(lower(common_all_labels), lower(common_bad_labels)));
% Keep rates with labels in common_labels and compute total rates and durations
common_values = zeros(length(common_all_labels),size(all_rates{1},2));
all_durations = 0;
for i = 1:length(all_labels)
    [~, label_idx]  = ismember(common_all_labels, all_labels{i});
    temp = all_rates{i}(label_idx,:).*repmat(cell2mat(all_info{i}(4:end-1)),length(common_all_labels),size(all_rates{i},2)/4);
    common_values = common_values + temp;
    all_durations = all_durations + cell2mat(all_info{i}(4:end-1));
end
common_values = common_values./repmat(all_durations,length(common_all_labels),size(all_rates{1},2)/4);

%% Export the combined results to a separate Excel sheet
fprintf(2,'\n======           Export combined rates for file "%s"            ======\n', file_name);
all_start_times = cellfun(@(x) x{2}, all_info);
all_end_times   = cellfun(@(x) x{3}, all_info);
mf_info{1,1} = "Multiple files";
mf_info{2,1} = string(min(datetime(all_start_times,'Format','dd-MMMM-yyyy HH:mm:ss.SSSSSSSSS')));
mf_info{3,1} = string(max(datetime(all_end_times,'Format','dd-MMMM-yyyy HH:mm:ss.SSSSSSSSS')));
mf_info{4,1} = all_durations(1);
mf_info{5,1} = all_durations(2);
mf_info{6,1} = all_durations(3);
mf_info{7,1} = all_durations(4);
mf_info{8,1} = "NaN" + " denotes bad channels";
for i = 1:length(user_measure)
    save_status = false;
    max_attempts = 10;
    attempt = 0;
    while ~save_status && attempt < max_attempts
        attempt = attempt + 1;
        try
            excelfile = fullfile(data_dir,"Excel Results","detections_pat" + ...
                subj_num + "_" + user_measure(i) + ".xlsx");
            sheet_name = "files combined";
            st = 1 + (i-1)*4; fi = 4*i;
            export_detections_to_excel(excelfile, sheet_name, mf_info, ...
                common_all_labels, user_measure(i), common_values(:,st:fi), ...
                common_values(:,(4*length(user_measure)) + (st:fi)), bad_idx);
            save_status = true;
        catch ME
            fprintf("Saving attempt %d/%d failed!\n", attempt, max_attempts);
            fprintf("Reason: %s\n",ME.message);
            fprintf("Re-Saving\n");
            pause(1);
        end
    end
    if ~save_status
        error("File could not be saved after %d attempts!", max_attempts);
    end
end
out = "The program has finished";
diary off; % close the log file
end