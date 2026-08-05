subj_nums = [12,19,20,21,22,23,24,25,26,27,28,29,30];%,23,25,26,27]; % subject number
fs = 2048;
j=1;
ops = zeros(13,3);
for subj_num = subj_nums
    data_dir = "/projects3/EPIHFO/EPIHFO/CNN results/Pat" + string(subj_num);   
    load(data_dir);
    
    CNN_probabilities = CNNresults.CNN_map;    
    sleep_samples = CNNresults.sleep_samples;

    total_per_t = sum(CNN_probabilities,1);

    artefact_samples = CNNresults.artefact_samples;
    artefact_vector = zeros(size(total_per_t));
    for i = 1:size(artefact_samples,1)
        s = floor(artefact_samples(i,1)/(3*fs));
        e = ceil(artefact_samples(i,2)/(3*fs));
        artefact_vector(s:e) = true;
    end
   
    [total_per_c,ind] = sort(sum(CNN_probabilities,2), 'descend');
    badchannels = CNNresults.badchannels(ind);


    [total_per_t, ind] = sort(total_per_t, 'descend');
    artefact_vector = artefact_vector(ind);
    
    %figure; hold on;
    %yyaxis right
    [X,Y,T,AUC] = perfcurve(artefact_vector,total_per_t, true);
    %plot(X,Y); xlabel('False positive rate'); ylabel('True positive rate');
    %plot([0 1], [0 1], 'k--');
    [val,i] = max(Y .* (1-X));
    %plot(X(i),Y(i),'k*')
    %xline(X(i), 'k:')
    %yline(Y(i),'k:')
    %yyaxis left
    %plot(X,[total_per_t,0])
    %title(sprintf('ROC AUC = %.3f\nOP: (%.3f, %.3f)', AUC, X(i), Y(i)));
    ops(j,:) = [X(i),Y(i), AUC];
    j = j+1;
end

avg_op = mean(ops(:,1));
accs = zeros(13,1);
corrcoef = zeros(13,1);
j = 1;
for subj_num = subj_nums
    data_dir = "/projects3/EPIHFO/EPIHFO/CNN results/Pat" + string(subj_num);   
    load(data_dir);
    
    CNN_probabilities = CNNresults.CNN_map;    
    sleep_samples = CNNresults.sleep_samples;

    total_per_t = sum(CNN_probabilities,1);

    artefact_samples = CNNresults.artefact_samples;
    artefact_vector = zeros(size(total_per_t));
    for i = 1:size(artefact_samples,1)
        s = floor(artefact_samples(i,1)/(3*fs));
        e = ceil(artefact_samples(i,2)/(3*fs));
        artefact_vector(s:e) = true;
    end

    [total_per_t, ind] = sort(total_per_t, 'descend');
    artefact_vector = artefact_vector(ind);
    
    cutoff = round(size(total_per_t,2)*avg_op);
    artefact_labels = zeros(size(total_per_t));
    artefact_labels(1:cutoff) = 1;

    corrcoef(j,1) = corr(artefact_vector',artefact_labels');
    C = confusionmat(artefact_vector, artefact_labels);
    accs(j) = (C(1,1)+C(2,2))/(C(1,1)+C(1,2)+C(2,1)+C(2,2));
    j = j+1;
end
