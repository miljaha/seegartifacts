% get the most artefactual channels by CNN and compare them to marked
% artefacts, also get the names of these channels
subj_nums = [12];%,19,20,21,22,23,24,25,26,27,28,29]; % subject number

for subj_num = subj_nums
    data_dir = "/projects3/EPIHFO/EPIHFO/CNN results/Pat" + string(subj_num);
    fs = 2048;
    windowSize = 3*fs;
    
    load(data_dir);
    
    CNN_probabilities = CNNresults.CNN_map;
    artefact_samples = CNNresults.artefact_samples;
    badchannels = CNNresults.badchannels;
    sleep_samples = CNNresults.sleep_samples;
    
    total_per_t = sum(CNN_probabilities,1);
    total_per_c = sum(CNN_probabilities,2);
    
    % convert shifted artefact samples into segment/timepoint units (matching CNN_probabilities columns)
    artefact_segments = artefact_samples / windowSize; % fractional segment index, x-axis units
    
    filename = "/projects3/EPIHFO/EPIHFO/Pat" + string(subj_num) + "/detection_rates_pat"+string(subj_num)+".xls";
    channels_names = string(table2cell(readtable(filename,"Sheet", "files combined", "Range","B11:B200",'VariableNamingRule','preserve','ReadVariableNames',false)));
    channels_names = channels_names(channels_names ~= "");  

    nums = 1:length(badchannels);
    [total_per_c_sorted, ind] = sort(total_per_c,'descend');
    badchannels_sorted = badchannels(ind);
    channels_names_sorted = channels_names(ind);
    nums_sorted = nums(ind)';

    results = [channels_names_sorted, nums_sorted, badchannels_sorted,total_per_c_sorted];

end