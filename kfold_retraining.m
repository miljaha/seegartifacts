artefacts = load("extracted_artefacts.mat");
controls = load("extracted_good_samples.mat");
good_nums = load("patient_number_good.mat");
controls.ids = good_nums.patient_number;
art_ids = load("patient_number_artefacts.mat");
artefacts.ids = art_ids.patient_number; 

clear art_ids good_nums
%
load("convnet.mat")
%
patients = unique(artefacts.ids);
n = numel(patients);

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
%%  Extract the final test set
seed = 67;
rng(seed)
artefacts.extracted_samples = single(artefacts.extracted_samples);
artefacts.ids = single(artefacts.ids);
controls.extracted_samples = single(controls.extracted_samples);
controls.ids = single(controls.ids);
%
n_artefact_samples = size(artefacts.extracted_samples, 3);
n_control_samples  = size(controls.extracted_samples, 3);
test_frac = 0.92;
val_frac = 0.04;

perm = randperm(n_artefact_samples);
artefacts.extracted_samples = artefacts.extracted_samples(:,:,perm);
artefacts.ids = artefacts.ids(perm);

perm = randperm(n_control_samples);
controls.extracted_samples = controls.extracted_samples(:,:,perm);
controls.ids = controls.ids(perm);

test_artefacts = artefacts.extracted_samples(:,:,1:round(test_frac * n_artefact_samples));
test_a_ids = artefacts.ids(1:round(test_frac * n_artefact_samples));
test_controls = controls.extracted_samples(:,:,1:round(test_frac * n_control_samples));
test_c_ids = controls.ids(1:round(test_frac * n_control_samples));

train_artefacts = artefacts.extracted_samples(:,:,round(test_frac * n_artefact_samples)+1:round((test_frac+val_frac)*n_artefact_samples));
train_a_ids = artefacts.ids(round(test_frac * n_artefact_samples)+1:round((test_frac+val_frac)*n_artefact_samples));
train_controls = controls.extracted_samples(:,:,round(test_frac * n_control_samples)+1:round((test_frac+val_frac)*n_control_samples));
train_c_ids = controls.ids(round(test_frac * n_control_samples)+1:round((test_frac+val_frac)*n_control_samples));

val_artefacts = artefacts.extracted_samples(:,:,round((test_frac+val_frac)*n_artefact_samples)+1:end);
val_a_ids = artefacts.ids(round((test_frac+val_frac)*n_artefact_samples)+1:end);
val_controls = controls.extracted_samples(:,:,round((test_frac+val_frac)*n_control_samples)+1:end);
val_c_ids = controls.ids(round((test_frac+val_frac)*n_control_samples)+1:end);

%%
% training / validation set preparation
X_train = cat(3,train_artefacts,train_controls);
X_train = reshape(X_train, size(X_train,1), size(X_train,2), 1, size(X_train,3));
train_pat_ids = [train_a_ids, train_c_ids]';
Y_train = [repmat(1,size(train_a_ids)), repmat(2,size(train_c_ids)),3];
Y_train = categorical(Y_train, [1 2 3], {'noise','ok','patology'});
Y_train = Y_train(1:end-1);

X_val = cat(3,val_artefacts,val_controls);
X_val = reshape(X_val,   size(X_val,1),   size(X_val,2),   1, size(X_val,3));
val_pat_ids = [val_a_ids, val_c_ids]';
Y_val = [repmat(1,size(val_a_ids)), repmat(2,size(val_c_ids)),3];
Y_val = categorical(Y_val, [1 2 3], {'noise','ok','patology'});
Y_val = Y_val(1:end-1);

X_test = cat(3,test_artefacts,test_controls);
X_test = reshape(X_test, size(X_test,1), size(X_test,2), 1, size(X_test,3));
test_pat_ids = [test_a_ids, test_c_ids]';
Y_test = [repmat(1,size(test_a_ids)), repmat(2,size(test_c_ids)),3];
Y_test = categorical(Y_test, [1 2 3], {'noise','ok','patology'});
Y_test = Y_test(1:end-1);

%% Retrain CNN
layers = convnet.Layers; % get original layers

options = trainingOptions('sgdm', ...
    'InitialLearnRate', 1e-4, ...   % gentle nudge, low LR
    'MaxEpochs', 10, ...
    'MiniBatchSize', 64, ...
    'Momentum', 0.9, ...
    'L2Regularization', 0.01, ...
    'ValidationData', {X_val, Y_val}, ...
    'ValidationFrequency', 30, ...
    'ValidationPatience',5,...
    'Plots','training-progress');

% retraining
net = trainNetwork(X_train, Y_train, layers, options);

%% k-fold (10-fold) validation using 0.92 test data
n_folds = 10;
subjects = unique(test_pat_ids);
n_patients = numel(subjects);

cv = cvpartition(n_patients,'KFold',n_folds);
results = cell(n_folds,1);
clear X_train Y_train X_val Y_val artefacts controls test_a_ids test_c_ids train_a_ids train_c_ids val_a_ids val_c_ids 
%%
for k = 1:n_folds
    test_patient_mask = test(cv, k);
    fold_ids = subjects(test_patient_mask);
    seg_mask = ismember(test_pat_ids, fold_ids);
    X_fold = X_test(:,:,:,seg_mask);
    Y_fold = Y_test(seg_mask);
    
    
    % --- evaluate on test ---
    Y_pred = classify(net, X_fold,MiniBatchSize=32);
    acc = mean(Y_pred == Y_fold');
    fprintf('Fold %d test accuracy: %.3f\n', k, acc);
    
    fold_results{k}.Y_true = Y_fold;
    fold_results{k}.Y_pred = Y_pred;
    fold_results{k}.patient_ids = test_pat_ids(seg_mask);
    fold_results{k}.acc = acc;
    
end

%%
acc = [];
for k = 1:n_folds
    acc(end+1) = fold_results{k}.acc;
end

fprintf("Mean accuracy: %.3f, sd of accuracy: %.3f\n", mean(acc),std(acc))

accs = cellfun(@(f) f.acc, fold_results);

figure;
bar(accs);
hold on;
yline(mean(accs), 'r--', sprintf('Mean = %.3f', mean(accs)), 'LineWidth', 1.5);
xlabel('Fold');
ylabel('Accuracy');
title('Accuracy per Fold');
ylim([0 1]);
xticks(1:n_folds);
grid on;