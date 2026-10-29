%% Define subject
patients = [12,19,20,21,22,23,24,25,26,28,27,29,30,31,32,33,34,35,36,37,38,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60];
n_max = 50;
n_max_row = 5;
include_bad = 0; % show samples in bad channels in gui, 0 = no, 1 = yes
all_info = [];
all_samples = [];
all_info_allchans = [];
all_samples_allchans = [];
for p = 1:18 % jatketaan illaks 19

    subj_num = patients(p);
    data_dir = "/projects3/EPIHFO/EPIHFO/Pat" + string(subj_num);

    %% Get CNN map for sample extraction
    address = "/projects3/EPIHFO/EPIHFO/seegartifacts/maps/Pat" + string(subj_num);
    saved = dir(address + "*");

    if ~isempty(saved)
        fprintf("%d map(s) saved for subject %d, using them to extract samples\n",numel(saved),subj_num)
        for k = 1:numel(saved)
            load(fullfile(saved(k).folder, saved(k).name));
            CNN_cell = patient_data.CNNmap;
            data_original = patient_data.broadband;
            data_hfb = patient_data.hfb;
            bipolar_labels = patient_data.labels;
            bad_channel_idx = patient_data.badchannels;
            artefact_samples = patient_data.artifacts;

            %% Get desired samples
            [signal_samples,info] = get_gui_samples(CNN_cell, data_original, data_hfb, bipolar_labels, bad_channel_idx, n_max, n_max_row, include_bad);
            info = [info,num2cell(repmat(subj_num,n_max,1))];

            all_samples = cat(3, all_samples, signal_samples);
            all_info    = [all_info; info];
    
            % keep only the n_max highest scores overall
            scores = cell2mat(all_info(:,1));
            [~, ord] = sort(scores, 'descend');
            ord = ord(1:min(n_max, numel(ord)));
            all_samples = all_samples(:,:,ord);
            all_info    = all_info(ord,:);

            [signal_samples_allchans,info_allchans] = get_gui_samples(CNN_cell, data_original, data_hfb, bipolar_labels, bad_channel_idx, n_max, n_max_row, 1);
            info_allchans = [info_allchans,num2cell(repmat(subj_num,n_max,1))];

            % merge with what we already have
            all_samples_allchans = cat(3, all_samples_allchans, signal_samples_allchans);
            all_info_allchans    = [all_info_allchans; info_allchans];
    
            % keep only the n_max highest scores overall
            scores = cell2mat(all_info_allchans(:,1));
            [~, ord] = sort(scores, 'descend');
            ord = ord(1:min(n_max, numel(ord)));
            all_samples_allchans = all_samples_allchans(:,:,ord);
            all_info_allchans    = all_info_allchans(ord,:);
        end
        
    else

        fprintf("No saved maps for subject %d, starting classifying the data\n",subj_num)
        address = "/projects3/EPIHFO/EPIHFO/seegartifacts/gui_samples/Pat" + string(subj_num);
        get_artefact_map(subj_num, data_dir);
        saved = dir(address + "*");
        for k = 1:numel(saved)
            load(fullfile(saved(k).folder, saved(k).name));
            CNN_cell = patient_data.CNNmap;
            data_original = patient_data.broadband;
            data_hfb = patient_data.hfb;
            bipolar_labels = patient_data.labels;
            bad_channel_idx = patient_data.badchannels;
            artefact_samples = patient_data.artifacts;

            [signal_samples,info] = get_gui_samples(CNN_cell, data_original, data_hfb, bipolar_labels, bad_channel_idx, n_max, n_max_row, include_bad);
            info = [info,num2cell(repmat(subj_num,n_max,1))];

            % merge with what we already have
            all_samples = cat(3, all_samples, signal_samples);
            all_info    = [all_info; info];
    
            % keep only the n_max highest scores overall
            scores = cell2mat(all_info(:,1));
            [~, ord] = sort(scores, 'descend');
            ord = ord(1:min(n_max, numel(ord)));
            all_samples = all_samples(:,:,ord);
            all_info    = all_info(ord,:);
        
            %% same but including bad channels
            [signal_samples_allchans,info_allchans] = get_gui_samples(CNN_cell, data_original, data_hfb, bipolar_labels, bad_channel_idx, n_max, n_max_row, 1);
            info_allchans = [info_allchans,num2cell(repmat(subj_num,n_max,1))];

            % merge with what we already have
            all_samples_allchans = cat(3, all_samples_allchans, signal_samples_allchans);
            all_info_allchans    = [all_info_allchans; info_allchans];
    
            % keep only the n_max highest scores overall
            scores = cell2mat(all_info_allchans(:,1));
            [~, ord] = sort(scores, 'descend');
            ord = ord(1:min(n_max, numel(ord)));
            all_samples_allchans = all_samples_allchans(:,:,ord);
            all_info_allchans    = all_info_allchans(ord,:);
        end
    end
    gui_data.samples = all_samples;
    gui_data.info = all_info;

    address = "/projects3/EPIHFO/EPIHFO/seegartifacts/gui_samples/good_channels/Pat" + string(subj_num);
    save(address, "gui_data","-v7.3");

    gui_data.samples = all_samples_allchans;
    gui_data.info = all_info_allchans;

    address = "/projects3/EPIHFO/EPIHFO/seegartifacts/gui_samples/all_channels/Pat" + string(subj_num);
    save(address, "gui_data","-v7.3");
    
end

%% Run GUI for all subjects that have gui data saved
for i = 1:numel(patients)
    subj_num = patients(i);
    datapath = "/projects3/EPIHFO/EPIHFO/seegartifacts/gui_samples/good_channels/Pat" + string(subj_num +'.mat'); % good_channels or all_channels

    if ~isfile(datapath); warning('No GUI data for patient %d, skipping.', subj_num); continue; end % no gui samples: run the code above
    S = load(datapath);
    if all(cellfun(@double, S.gui_data.info(:,6)) > 0); continue; end          % everything labeled already

    labelSignals(datapath);
end