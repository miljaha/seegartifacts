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
%%
load("convnet.mat")
%
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

%
[min_a, ind_a] = min(artefact_counts);
[min_c, ind_c] = min(control_counts);

n_samples = min(min_a, min_c);

%% LOSO
layers = convnet.Layers; % get original layers

options = trainingOptions('sgdm', ...
    'InitialLearnRate', 1e-4, ...   % gentle nudge, low LR
    'MaxEpochs', 10, ...
    'MiniBatchSize', 64, ...
    'Momentum', 0.9, ...
    'L2Regularization', 0.01, ...
    'Plots','none');

I = repmat(1:n,n,1)';
testing_idx = I(logical(eye(n)));
training_idx = reshape(I(~eye(n)), n-1, n)';

results = cell(0,0);

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
save("seegartifacts/LOSO/LOSO_results","results")
%% --- 1 Quantify the artefact classification performance using accuracy, sensitivity, specificity, F1-score, AUC-ROC, AUPRC, and the confusion matrix. ---
load('/net/sigma/fishpool3/projects3/EPIHFO/EPIHFO/seegartifacts/LOSO/LOSO_results.mat')
patients = [49,12,19,20,21,22,23,24,25,26,27,28,29,30, 31,32,33,34,35,36,37,38,40,41,42,43,44,45,46,47,48,50,51,52,53,54,55,56,57,58,59,60];

acc = zeros(1,n);
ppv = zeros(1,n);
spec = zeros(1,n);
sens = zeros(1,n);
F1 = zeros(1,n);
aucroc = zeros(1,n);
auprc = zeros(1,n);
for i = 1:n
    acc(i) = results{i}.acc;
    Y_true = results{i}.Y_true;
    Y_pred = results{i}.Y_pred;
    scores = results{i}.scores;

    TP = sum(Y_true == 'noise' & Y_pred' == 'noise');
    FP = sum(Y_true == 'ok' & Y_pred' == 'noise');
    FN = sum(Y_true == 'noise' & Y_pred' == 'ok');
    TN = sum(Y_true == 'ok' &  Y_pred' == 'ok');
    ppv(i) = TP/(TP+FP); % noise actually being noise
    spec(i) = TN/(TN+FP); % ok classified as ok
    sens(i) = TP/(TP+FN);
    F1(i) = 2*(ppv(i)*sens(i)) ./ (ppv(i)+sens(i));
    
    % AUC_ROC
    [~,~,~,aucroc(i)] = perfcurve(Y_true, scores(:,1), 'noise');
    [~,~,~,auprc(i)] = perfcurve(Y_true, scores(:,1), 'noise','xCrit','reca','yCrit','prec');

end

figure;
plot(1:n, acc, '-o', 'MarkerFaceColor','auto'); hold on
plot(1:n, ppv, '-o', 'MarkerFaceColor','auto');
plot(1:n, spec, '-o', 'MarkerFaceColor','auto');
xticks(1:n)
xticklabels(patients)
title("Per-subject testing of retrained CNN");
xlabel("Subject")
ylabel("Metrics")
legend("Accuracy", "PPV", "Specificity", Location="southeast")
ylim([-0.05 1.05])

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

tiledlayout(7,6)
savefilename = fullfile('/projects3/EPIHFO/EPIHFO/seegartifacts/LOSO/confusionmatrix.svg');

for i = 1:n
    nexttile;

    Y_true = mergecats(results{i}.Y_true,{'ok','patology'}, 'ok') ;
    Y_pred = results{i}.Y_pred;

    confusionchart(Y_true, Y_pred')
    text = "Patient "+string(patients(i));
    title(text);
 
end

 saveas(gcf, savefilename);

%% Probability maps for each subject

% lataa data ja network for each subject
for i = 1:1 % 1:n
    subj_num = patients(i);
    convnet = results{i}.net;
    out = LOSO_CNN_map(subj_num, convnet);
    fprintf("Probability map for subject %d saved", subj_num);
end

%% Predict bad channels and artifact times

