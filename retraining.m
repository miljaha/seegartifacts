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

%
[min_a, ind_a] = min(artefact_counts);
[min_c, ind_c] = min(control_counts);

n_samples = min(min_a, min_c);

% select n samples for retraining
selected_artefacts = zeros(5,15000,0);
artefacts_idx = [];
selected_controls = zeros(5,15000,0);
controls_idx = [];

for i = 1:numel(patients)
    % artefacts
    idx = find(artefacts.ids == patients(i));
    idx_first_n = idx(1:n_samples); 
    artefacts_idx = [artefacts_idx, idx_first_n];
    selected_artefacts(:,:,end+1:end+22) = artefacts.extracted_samples(:,:,idx_first_n);

    % ctonrols
    idx = find(controls.ids == patients(i));
    idx_first_n = idx(1:n_samples); 
    controls_idx = [controls_idx, idx_first_n];
    selected_controls(:,:,end+1:end+22) = controls.extracted_samples(:,:,idx_first_n);
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

clear X_train Y_train
%
testset_artefacts = struct();
testset_controls = struct();

testset_artefacts_mask = true(numel(artefacts.ids), 1);
testset_artefacts_mask(artefacts_idx) = false;
testset_artefacts.ids = artefacts.ids(testset_artefacts_mask);
testset_artefacts.samples = artefacts.extracted_samples(:,:,testset_artefacts_mask);

testset_controls_mask = true(numel(controls.ids), 1);
testset_controls_mask(controls_idx) = false;
testset_controls.ids = controls.ids(testset_controls_mask);
testset_controls.samples = controls.extracted_samples(:,:,testset_controls_mask);


