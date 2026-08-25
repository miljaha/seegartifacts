artefacts = load("extracted_artefacts.mat");
controls = load("extracted_good_samples.mat");
good_nums = load("patient_number_good.mat");
controls.ids = good_nums.patient_number;
art_ids = load("patient_number_artefacts.mat");
artefacts.ids = art_ids.patient_number; 

clear art_ids good_nums

load("convnet.mat")

%% Extract the final test set
rng(67)
artefacts.extracted_samples = single(artefacts.extracted_samples);
controls.extracted_samples = single(controls.extracted_samples);
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
test_c_idx = controls.ids(1:round(test_frac * n_control_samples));

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
[dev_idx, final_test_idx] = make_final_split(all_ids, all_labels, seed);
folds = make_cv_folds(dev_idx, all_ids, all_labels, n_folds, seed);

for i = 1:n_folds
    [train_idx, val_idx] = split_and_balance(folds{i}.train_pool_idx, all_labels, val_fraction, i);
    test_idx = folds{i}.test_idx;
    
    fprintf('Fold %d: train=%d, val=%d, test=%d\n', i, numel(train_idx), numel(val_idx), numel(test_idx));
    
    % --- evaluate on test ---
    Y_pred = classify(net, X_test_4d);
    acc = mean(Y_pred == Y_test);
    fprintf('  Fold %d test accuracy: %.3f\n', i, acc);
    
    results{i} = struct('net', net, 'test_idx', test_idx, 'accuracy', acc);
    
    % --- free memory before next fold ---
    clear X_train X_val X_test X_train_4d X_val_4d X_test_4d net
end

%% functions

function X = get_samples(idx, artefacts, controls, n_artefact)
    % idx values <= n_artefact come from artefacts, rest from controls (shifted)
    is_artefact = idx <= n_artefact;
    art_idx  = idx(is_artefact);
    ctrl_idx = idx(~is_artefact) - n_artefact;
    
    X = cat(3, artefacts.extracted_samples(:,:,art_idx), ...
               controls.extracted_samples(:,:,ctrl_idx));
end

function folds = make_inverted_folds(ids, labels, n_folds, seed)
    rng(seed);
    unique_ids = unique(ids);
    patient_labels = arrayfun(@(id) mode(labels(ids == id)), unique_ids);
    
    cv = cvpartition(patient_labels, 'KFold', n_folds);
    
    folds = cell(n_folds, 1);
    for i = 1:n_folds
        train_pool_patients = unique_ids(training(cv, i));
        test_patients        = unique_ids(test(cv, i));
        
        train_pool_idx = find(ismember(ids, train_pool_patients));
        test_idx       = find(ismember(ids, test_patients));
        
        folds{i} = struct('train_pool_idx', train_pool_idx, 'test_idx', test_idx);
    end
end

function [train_idx, val_idx] = split_and_balance(train_pool_idx, labels, val_fraction, seed)
    rng(seed);
    n_val = round(numel(train_pool_idx) * val_fraction);
    shuffled = train_pool_idx(randperm(numel(train_pool_idx)));
    
    val_idx   = shuffled(1:n_val);
    train_idx = shuffled(n_val+1:end);
    
    train_idx = balance_classes(train_idx, labels, seed);
    val_idx   = balance_classes(val_idx, labels, seed+1);
end

function balanced_idx = balance_classes(idx, labels, seed)
    rng(seed);
    lbls = labels(idx);
    classes = unique(lbls);
    counts = arrayfun(@(c) sum(lbls == c), classes);
    min_count = min(counts);
    
    balanced_idx = [];
    for c = classes'
        class_idx = idx(lbls == c);
        sel = class_idx(randperm(numel(class_idx), min_count));
        balanced_idx = [balanced_idx; sel]; %#ok<AGROW>
    end
    balanced_idx = balanced_idx(randperm(numel(balanced_idx)));
end