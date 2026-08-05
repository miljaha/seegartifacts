subj_nums = [22]%,23,25,26,27]; % subject number
fs = 2048;

for subj_num = subj_nums
    data_dir = "/projects3/EPIHFO/EPIHFO/CNN results/Pat" + string(subj_num)+"_new";   
    load(data_dir);
    
    CNN_probabilities = CNNresults.CNN_map;    
    sleep_samples = CNNresults.sleep_samples;

    CNN_probabilities = CNN_probabilities - std(CNN_probabilities,0,2); % normalize
    total_per_t = zscore(sum(CNN_probabilities,1));

    artefact_samples = CNNresults.artefact_samples;
    artefact_vector = zeros(size(total_per_t));
    for i = 1:size(artefact_samples,1)
        s = floor(artefact_samples(i,1)/(3*fs));
        e = ceil(artefact_samples(i,2)/(3*fs));
        artefact_vector(s:e) = true;
    end
   
    total_per_c = zscore(sum(CNN_probabilities,2));
    badchannels = CNNresults.badchannels;

    [total_per_t, ind] = sort(total_per_t, 'descend');
    artefact_vector = artefact_vector(ind);
    sliding = zeros(size(artefact_vector,2)-9,1);
    for i = 1:size(artefact_vector,2)-9
        sliding(i) = sum(artefact_vector(i:i+9));
    end

    figure; hold on;
    plot(total_per_t), plot(sliding)
end