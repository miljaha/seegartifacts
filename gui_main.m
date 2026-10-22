%% Define subject
patients = [12,19,20,21,22,23,24,25,26,28,27,29,30,31,32,33,34,35,36,37,38,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60];

all_info = [];
all_samples = [];
for p = 1:length(patients)

    subj_num = patients(p);
    data_dir = "/projects3/EPIHFO/EPIHFO/Pat" + string(subj_num);

    %% Get CNN map for sample extraction
    [CNN_cell, data_original,data_hfb, bipolar_labels,bad_channel_idx] = get_artefact_map(subj_num, data_dir);
    
    %% Get desired 100 samples
    [signal_samples,info] = get_gui_samples(CNN_cell, data_original, data_hfb, bipolar_labels, bad_channel_idx);

    info = [info,repmat(subj_num,100,1)];
    all_info = [all_info; info];
    all_samples = cat(3,all_samples, signal_samples);
end
%% Start GUI
chanNames = cellstr(string(bipolar_labels(info(:,2))));
labelSignals(signal_samples, info, chanNames, 2048, 'labels.mat', true, true);