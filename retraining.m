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
%%

% select n samples for retraining
selected_artefacts = zeros(5,15000,0);
artefacts_idx = [];
selected_controls = zeros(5,15000,0);
controls_idx = [];

for i = 1:numel(patients)
    % artefacts
    idx = find(artefacts.ids == patients(i));
    rng(67);
    idx_n = randperm(length(idx), n_samples); 
    artefacts_idx = [artefacts_idx, idx_n];
    selected_artefacts(:,:,end+1:end+22) = artefacts.extracted_samples(:,:,idx_n);

    % controls
    idx = find(controls.ids == patients(i));
    rng(68)
    idx_n =  randperm(length(idx), n_samples); 
    controls_idx = [controls_idx, idx_n];
    selected_controls(:,:,end+1:end+22) = controls.extracted_samples(:,:,idx_n);
end


X_train = cat(3,selected_controls,selected_artefacts);
X_train = reshape(X_train, size(X_train,1), size(X_train,2), 1, size(X_train,3));
Y_train = [repmat(2,1,numel(patients)*n_samples), repmat(1,1,numel(patients)*n_samples),3];
Y_train = categorical(Y_train, [1 2 3], {'noise','ok','patology'});
Y_train = Y_train(1:end-1);


layers = convnet.Layers; % get original layers

options = trainingOptions('sgdm', ...
    'InitialLearnRate', 1e-4, ...   % gentle nudge, low LR
    'MaxEpochs', 10, ...
    'MiniBatchSize', 64, ...
    'Momentum', 0.9, ...
    'L2Regularization', 0.01, ...
    'Plots','training-progress');
    %'ValidationData', {X_val, Y_val}, ...
    %'ValidationFrequency', 30, ...
    %'ValidationPatience',5,...
    

% retraining
net = trainNetwork(X_train, Y_train, layers, options);
%
clear X_train Y_train selected_artefacts selected_controls

% free RAM by removing the samples you already copied into X_train
%artefacts.extracted_samples(:,:,artefacts_idx) = [];
%artefacts.ids(artefacts_idx) = [];

%controls.extracted_samples(:,:,controls_idx) = [];
%controls.ids(controls_idx) = [];
%% leave out the samples used for training

testset_artefacts_mask = true(numel(artefacts.ids), 1);
testset_artefacts_mask(artefacts_idx) = false;

testset_controls_mask = true(numel(controls.ids), 1);
testset_controls_mask(controls_idx) = false;


% leave one out
results = cell(n,1);

for k = 1:n % k is the leave-out patient
    fprintf("Starting fold %d\n",k)
    %{
    if k == 1; included_pats = patients(2:end);
    elseif k == n; included_pats = patients(1:n-1);
    else; included_pats = patients([1:k-1,k+1:end]); 
    end
    %}
    included_pats = patients(k);

    fold_mask_artifacts = ismember(artefacts.ids, included_pats); %& testset_artefacts_mask;
    fold_artifacts = artefacts.extracted_samples(:,:,fold_mask_artifacts);
    fold_mask_controls = ismember(controls.ids, included_pats); % & testset_controls_mask;
    fold_controls = controls.extracted_samples(:,:,fold_mask_controls);

    X_fold = cat(3, fold_artifacts, fold_controls);
    X_fold = reshape(X_fold, size(X_fold,1), size(X_fold,2), 1, size(X_fold,3));
    Y_fold = [repmat(1,1,size(fold_artifacts,3)), repmat(2,1,size(fold_controls,3))];
    Y_fold = categorical(Y_fold, [1 2 3], {'noise','ok','patology'});
    clear fold_artifacts fold_controls

    % --- evaluate on test ---
    Y_pred = classify(net, X_fold,MiniBatchSize=32);
    Y_pred  = mergecats(Y_pred,  {'ok','patology'}, 'ok');
    acc = mean(Y_pred == Y_fold');
    fprintf('Fold %d test accuracy: %.3f\n', k, acc);
    
    results{k}.Y_true = Y_fold;
    results{k}.Y_pred = Y_pred;
    results{k}.acc = acc;

    clear X_fold Y_fold
   
end
%%
acc = zeros(1,n);
ppv = zeros(1,n);
spec = zeros(1,n);
for i = 1:n
    acc(i) = results{i}.acc;
    Y_true = results{i}.Y_true;
    Y_pred = results{i}.Y_pred;

    TP = sum(Y_true == 'noise' & Y_pred' == 'noise');
    FP = sum(Y_true == 'ok' & Y_pred' == 'noise');
    FN = sum(Y_true == 'noise' & Y_pred' == 'ok');
    TN = sum(Y_true == 'ok' &  Y_pred' == 'ok');
    ppv(i) = TP/(TP+FP); % noise actually being noise
    spec(i) = TN/(TN+FP); % ok classified as ok
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

fprintf("Accuracy mean: %.3f, PPV mean: %.3f, Specificity mean: %.3f\n",mean(acc), mean(ppv), mean(spec))

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
    scores = results{k}.scores;

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

fprintf("Accuracy mean: %.3f \nPPV mean: %.3f \nSpecificity mean: %.3f \nSensitivity mean: %.3f\nF1-score mean: %.3f\n",mean(acc), mean(ppv), mean(spec),mean(sens),mean(F1))
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

