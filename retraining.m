%% --- load the artifact and normal samples ---

tmp = load("extracted_artefacts.mat");
artefacts.extracted_samples = single(tmp.extracted_samples);
clear tmp

tmp = load("extracted_good_samples.mat");
controls.extracted_samples = single(tmp.extracted_samples);
clear tmp

tmp = load("patient_number_good.mat");
controls.ids = single(tmp.patient_number);
clear tmp

tmp = load("patient_number_artefacts.mat");
artefacts.ids = single(tmp.patient_number);
clear tmp

%% load pretrained network
load("convnet.mat")

%% get number of samples per each patient
patients = unique(artefacts.ids);
n = numel(patients);
%
patient_col = patients(:);
artefact_counts = zeros(n,1);
control_counts = zeros(n,1);

for i = 1:n
    artefact_counts(i) = sum(artefacts.ids == patients(i));
    control_counts(i) = sum(controls.ids == patients(i));
end

numbers_of_samples = table(patient_col, artefact_counts, control_counts, ...
    'VariableNames', {'Patient', 'Artefacts', 'Controls'});
writetable(numbers_of_samples, 'sample_counts.xlsx');

% find minimum sample set size = used for retraining from each patient
[min_a, ind_a] = min(artefact_counts);
[min_c, ind_c] = min(control_counts);

n_samples = min(min_a, min_c);

%% LOSO retraining and validation

% prep the network and training
layers = convnet.Layers; % get original layers

options = trainingOptions('sgdm', ...
    'InitialLearnRate', 1e-4, ...   % gentle nudge, low LR
    'MaxEpochs', 10, ...
    'MiniBatchSize', 64, ...
    'Momentum', 0.9, ...
    'L2Regularization', 0.01, ...
    'Plots','none');

% testing and training sets for each fold
I = repmat(1:n,n,1)';
testing_idx = I(logical(eye(n)));
training_idx = reshape(I(~eye(n)), n-1, n)';

% prep results
results = cell(0,0);

% leave-one-subject-out
for k = 1:n % k is the leave-out patient
    k_th = patients(k); % loso subject
    others = patients(training_idx(k,:));
    % --- Training set ---
    % form the training set with n-1 subjects
    fold_mask_artifacts = ismember(artefacts.ids, others); %& testset_artefacts_mask;
    fold_artifacts = artefacts.extracted_samples(:,:,fold_mask_artifacts);
    fold_artifacts_id = artefacts.ids(fold_mask_artifacts);
    fold_mask_controls = ismember(controls.ids, others); % & testset_controls_mask;
    fold_controls = controls.extracted_samples(:,:,fold_mask_controls);
    fold_controls_id = controls.ids(fold_mask_controls);

    % select n_samples from each subject ("random")
    selected_artefacts = zeros(5,15000,0);
    selected_controls = zeros(5,15000,0);
    for i = 1:numel(training_idx(k,:))
        % artefacts
        idx = find(fold_artifacts_id == others(i));
        rng(67);
        idx_n = randperm(length(idx), n_samples); 
        selected_artefacts(:,:,end+1:end+22) = artefacts.extracted_samples(:,:,idx_n);
    
        % controls
        idx = find(fold_controls_id == others(i));
        rng(68)
        idx_n =  randperm(length(idx), n_samples); 
        selected_controls(:,:,end+1:end+22) = controls.extracted_samples(:,:,idx_n);
    end

    % form the training set
    X_train = cat(3, selected_artefacts, selected_controls);
    X_train = reshape(X_train, size(X_train,1), size(X_train,2), 1, size(X_train,3));
    Y_train = [repmat(1,1,size(selected_artefacts,3)), repmat(2,1,size(selected_controls,3))];
    Y_train = categorical(Y_train, [1 2 3], {'noise','ok','patology'});
    fprintf("Size of X_train: %d \n", size(X_train,4))

    % --- Retrain the CNN using x_train and y_train ---
    net = trainNetwork(X_train, Y_train, layers, options);
    fprintf("Network training successful!\n")
   
    % --- Testing set ---
    % select the kth subjects samples
    fold_mask_artifacts = ismember(artefacts.ids, k_th); %& testset_artefacts_mask;
    fold_artifacts = artefacts.extracted_samples(:,:,fold_mask_artifacts);
    fold_artifacts_id = artefacts.ids(fold_mask_artifacts);
    fold_mask_controls = ismember(controls.ids, k_th); % & testset_controls_mask;
    fold_controls = controls.extracted_samples(:,:,fold_mask_controls);
    fold_controls_id = controls.ids(fold_mask_controls);

    % select random 22 samples
    % artefacts
    idx = find(fold_artifacts_id == k_th);
    rng(67);
    idx_n = randperm(length(idx), n_samples); 
    selected_artefacts = artefacts.extracted_samples(:,:,idx_n);

    % controls
    idx = find(fold_controls_id == k_th);
    rng(68)
    idx_n =  randperm(length(idx), n_samples); 
    selected_controls = controls.extracted_samples(:,:,idx_n);

    % test set generation
    X_test = cat(3, selected_artefacts, selected_controls);
    X_test = reshape(X_test, size(X_test,1), size(X_test,2), 1, size(X_test,3));
    Y_test = [repmat(1,1,size(selected_artefacts,3)), repmat(2,1,size(selected_controls,3))];
    Y_test = categorical(Y_test, [1 2 3], {'noise','ok','patology'});
    fprintf("Size of testing set: %d\n", size(X_test,4))

    % --- Test the network ---
    [Y_pred, scores] = classify(net, X_test);
    Y_pred  = mergecats(Y_pred,  {'ok','patology'}, 'ok');
    acc = mean(Y_pred == Y_test');
    fprintf('Fold %d test accuracy: %.3f\n', k, acc); 

    % --- Save performance and net (?) ---
    results{k}.Y_true = Y_test;
    results{k}.Y_pred = Y_pred;
    results{k}.acc = acc;
    results{k}.net = net;
    results{k}.scores = scores;

    clear X_test Y_test X_train Y_train 
end
% save the results
save("seegartifacts/LOSO/LOSO_results","results")

%% --- 1 Quantify the artefact classification performance using accuracy, sensitivity, specificity, F1-score, AUC-ROC, AUPRC, and the confusion matrix. ---
load('/net/sigma/fishpool3/projects3/EPIHFO/EPIHFO/seegartifacts/LOSO/LOSO_results.mat')
patients = [12,19,20,21,22,23,24,25,26,27,28,29,30, 31,32,33,34,35,36,37,38,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60];

% prep the results
acc = zeros(1,n);
ppv = zeros(1,n);
spec = zeros(1,n);
sens = zeros(1,n);
F1 = zeros(1,n);
aucroc = zeros(1,n);
auprc = zeros(1,n);

for i = 1:n % for each patient
    % get the classes for true and predicted
    acc(i) = results{i}.acc;
    Y_true = results{i}.Y_true;
    Y_pred = results{i}.Y_pred;
    scores = results{i}.scores;

    % count categories
    TP = sum(Y_true == 'noise' & Y_pred' == 'noise');
    FP = sum(Y_true == 'ok' & Y_pred' == 'noise');
    FN = sum(Y_true == 'noise' & Y_pred' == 'ok');
    TN = sum(Y_true == 'ok' &  Y_pred' == 'ok');

    % count metrics
    ppv(i) = TP/(TP+FP); % noise actually being noise
    spec(i) = TN/(TN+FP); % ok classified as ok
    sens(i) = TP/(TP+FN);
    F1(i) = 2*(ppv(i)*sens(i)) ./ (ppv(i)+sens(i));
    [~,~,~,aucroc(i)] = perfcurve(Y_true, scores(:,1), 'noise');
    [~,~,~,auprc(i)] = perfcurve(Y_true, scores(:,1), 'noise','xCrit','reca','yCrit','prec');

end

% save results to table
metricNames = {'Accuracy','PPV','Specificity','Sensitivity','F1','AUC-ROC','AUPRC'};
means = [mean(acc), mean(ppv,'omitnan'), mean(spec,'omitnan'), mean(sens,'omitnan'), ...
         mean(F1,'omitnan'), mean(aucroc,'omitnan'), mean(auprc,'omitnan')];
sds   = [std(acc), std(ppv,'omitnan'), std(spec,'omitnan'), std(sens,'omitnan'), ...
         std(F1,'omitnan'), std(aucroc,'omitnan'), std(auprc,'omitnan')];

resultsTable = table(metricNames', means', sds', ...
    'VariableNames', {'Metric','Mean','SD'});
disp(resultsTable)
%% confusion matrix 
f = figure;
f.WindowState = 'fullscreen';
tiledlayout(7,6) % 42 subjects

for i = 1:n
    nexttile;

    % merge pathology and ok categories
    Y_true = mergecats(results{i}.Y_true,{'ok','patology'}, 'ok') ;
    Y_pred = results{i}.Y_pred;

    % plot the confusion matrix
    confusionchart(Y_true, Y_pred')
    text = "Patient "+string(patients(i));
    title(text);
end

% save figure
savefilename = fullfile('/projects3/EPIHFO/EPIHFO/seegartifacts/LOSO/confusionmatrix.svg');
saveas(gcf, savefilename);

%% Probability maps for each subject

% lataa data ja network for each subject
for i = 32:n % 1:n
    subj_num = patients(i);
    convnet = results{i}.net;
    out = LOSO_CNN_map(subj_num, convnet);
    fprintf("Probability map for subject %d saved", subj_num);
end

%% crop data to analyze only sleep time
for i = 1:n
    subj_num = patients(i);
    loadname = '/projects3/EPIHFO/EPIHFO/seegartifacts/LOSO/probabilitymap_Pat'+string(subj_num)+'_results.mat';
    load(loadname)

    sample_window = get_sample_window(subj_num);
    s = sample_window(1,1);
    e = sum(sample_window(2,:));
    sleep_samples = [s,e];

    shift = s / 2048; % how much was deleted from the beginning, in seconds
                  
    % how many samples from beginning and from end
    startblock = ceil(s/2048/3);
    endblock = ceil(e/2048/3);
    % leikkaa saatu CNN map näiden mukaan
    CNN_probabilities = results.map(:,startblock:min(endblock,size(results.map,2)));
    results.map = CNN_probabilities;

    % crop artefacts
    startsec = startblock*3;
    endsec = endblock*3;

    artefacts = results.artefacts;

    st = artefacts(:,1);
    en = artefacts(:,2);
    
    % remove artefacts entirely outside the window
    keep = ~(en < startsec | st > endsec);
    artefacts = artefacts(keep, :);
    
    % re-fetch st/en after filtering (rows have changed)
    st = artefacts(:,1);
    en = artefacts(:,2);
    
    % clip the ones that partially overlap the window edges
    st(st < startsec) = startsec;
    en(en > endsec) = endsec;
    artefacts = [st, en];
    artefacts = artefacts - shift;

    % save
    resultsname = '/projects3/EPIHFO/EPIHFO/seegartifacts/LOSO/probabilitymap_Pat'+string(subj_num)+'_results_sleeptimes.mat';
    results.artefacts = artefacts;
    save(resultsname,'results')
end 
%%
for i = 1:10
    subj_num = patients(i);
    resultsname = '/projects3/EPIHFO/EPIHFO/seegartifacts/LOSO/probabilitymap_Pat'+string(subj_num)+'_results_sleeptimes.mat';
    load(resultsname);
    visualize_CNN_LOSO(results,subj_num)
end
%% Predict bad channels and artifact times
prediction_results = struct();
thresholds = 3:0.5:10;
nPat = 42; % or numel(patients)
nTh = numel(thresholds);

acc_t_th = nan(nPat, nTh);
ppv_t_th = nan(nPat, nTh);
spec_t_th = nan(nPat, nTh);
sens_t_th = nan(nPat, nTh);
F1_t_th = nan(nPat, nTh);
acc_c_th = nan(nPat, nTh);
ppv_c_th = nan(nPat, nTh);
spec_c_th = nan(nPat, nTh);
sens_c_th = nan(nPat, nTh);
F1_c_th = nan(nPat, nTh);

for thIdx = 1:nTh
    th = thresholds(thIdx);
    for i = 1:nPat
        subj_num = patients(i);
        resultsname = '/projects3/EPIHFO/EPIHFO/seegartifacts/LOSO/probabilitymap_Pat'+string(subj_num)+'_results_sleeptimes.mat';
        load(resultsname)

        CNN_probabilities = results.map;
        total_per_t = log1p(mean(CNN_probabilities,1));
        total_per_c = log1p(mean(CNN_probabilities,2));

        badchannels = results.badchannels;
        artefact_segments = results.artefacts;

        % --- artifacts (time) ---
        med = median(total_per_t);
        MAD = median(abs(total_per_t - med));
        robust_z = 0.6745 * (total_per_t - med) / MAD;
        artefact_peaks = robust_z > th;

        nSegments = length(total_per_t);
        artefact_vec = zeros(1, nSegments);
        for j = 1:size(artefact_segments,1)
            startSeg = max(floor(artefact_segments(j,1)/3)+1, 1);
            endSeg = min(ceil(artefact_segments(j,2)/3), nSegments);
            artefact_vec(startSeg:endSeg) = 1;
        end

        TP = sum(artefact_vec & artefact_peaks);
        FP = sum(~artefact_vec & artefact_peaks);
        FN = sum(artefact_vec & ~artefact_peaks);
        TN = sum(~artefact_vec & ~artefact_peaks);

        acc_t_th(i,thIdx)  = (TP+TN)/(TP+FP+TN+FN);
        ppv_t_th(i,thIdx)  = TP/(TP+FP);
        spec_t_th(i,thIdx) = TN/(TN+FP);
        sens_t_th(i,thIdx) = TP/(TP+FN);
        F1_t_th(i,thIdx)   = 2*(ppv_t_th(i,thIdx)*sens_t_th(i,thIdx)) / (ppv_t_th(i,thIdx)+sens_t_th(i,thIdx));

        % --- bad channels ---
        med = median(total_per_c);
        MAD = median(abs(total_per_c - med));
        robust_z = 0.6745 * (total_per_c - med) / MAD;
        badchan_peaks = robust_z > th;

        TP = sum(badchannels & badchan_peaks);
        FP = sum(~badchannels & badchan_peaks);
        FN = sum(badchannels & ~badchan_peaks);
        TN = sum(~badchannels & ~badchan_peaks);

        acc_c_th(i,thIdx)  = (TP+TN)/(TP+FP+TN+FN);   % <- fixed, see below
        ppv_c_th(i,thIdx)  = TP/(TP+FP);
        spec_c_th(i,thIdx) = TN/(TN+FP);
        sens_c_th(i,thIdx) = TP/(TP+FN);
        F1_c_th(i,thIdx)   = 2*(ppv_c_th(i,thIdx)*sens_c_th(i,thIdx)) / (ppv_c_th(i,thIdx)+sens_c_th(i,thIdx));
    end
end

prediction_results.time.acc = acc_t_th;
prediction_results.time.ppv = ppv_t_th;
prediction_results.time.spec = spec_t_th;
prediction_results.time.sens = sens_t_th;
prediction_results.time.F1 = F1_t_th;
prediction_results.chans.acc = acc_c_th;
prediction_results.chans.ppv = ppv_c_th;
prediction_results.chans.spec = spec_c_th;
prediction_results.chans.sens = sens_c_th;
prediction_results.chans.F1 = F1_c_th;
prediction_results.iterated_th = thresholds;
%%
visualize_threshold_artefacts(50,200)
%% Plotting the results
metricNames = {'acc','ppv','spec','sens','F1'};
metricLabels = {'Accuracy','PPV','Specificity','Sensitivity','F1'};
thresholds = prediction_results.iterated_th;

% small jitter offsets, one per metric, centered around 0
nMetrics = numel(metricNames);
jitterAmount = 0.06; % tune this - fraction of your threshold step size
jitterOffsets = linspace(-jitterAmount*(nMetrics-1)/2, jitterAmount*(nMetrics-1)/2, nMetrics);

figure;

% --- Panel 1: Time-wise ---
subplot(1,2,1); hold on
for m = 1:nMetrics
    data = prediction_results.time.(metricNames{m});
    meanVals = mean(data, 1, 'omitnan');
    sdVals = std(data, 0, 1, 'omitnan');
    x_jittered = thresholds + jitterOffsets(m);
    errorbar(x_jittered, meanVals, sdVals, '-o', 'LineWidth', 1.2, 'MarkerSize', 4);
end
xlabel('Robust z-score threshold')
ylabel('Metric value')
title('Time-wise (artifact) performance')
legend(metricLabels, 'Location', 'southwest')
ylim([-0.05 1.05])
grid on
hold off

% --- Panel 2: Channel-wise ---
subplot(1,2,2); hold on
for m = 1:nMetrics
    data = prediction_results.chans.(metricNames{m});
    meanVals = mean(data, 1, 'omitnan');
    sdVals = std(data, 0, 1, 'omitnan');
    x_jittered = thresholds + jitterOffsets(m);
    errorbar(x_jittered, meanVals, sdVals, '-o', 'LineWidth', 1.2, 'MarkerSize', 4);
end
xlabel('Robust z-score threshold')
ylabel('Metric value')
title('Channel-wise (bad channel) performance')
legend(metricLabels, 'Location', 'southwest')
ylim([-0.05 1.05])
grid on
hold off
sgtitle('Threshold sweep: mean \pm SD across patients')



