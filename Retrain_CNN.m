%% Split data into training & testing & validation sets using 80/20/20 ratio

% number of samples to each group
n_train_TN = ceil(size(segment_TN,3)*0.8);
n_test_TN = (size(segment_TN,3)-n_train_TN)*0.5;

n_train_TP = ceil(size(segment_TP,3)*0.8);
n_test_TP = (size(segment_TP,3)-n_train_TP)*0.5; % = n_val

% shuffle segments and pick the samples
segment_TN = segment_TN(:,:,randperm(size(segment_TN,3)));
TN_train = segment_TN(:,:,1:n_train_TN);
TN_test = segment_TN(:,:,n_train_TN+1:n_train_TN+n_test_TN);
TN_val = segment_TN(:,:,n_train_TN+n_test_TN+1:end);

segment_TP = segment_TP(:,:,randperm(size(segment_TP,3)));
TP_train = segment_TP(:,:,1:n_train_TP);
TP_test = segment_TP(:,:,n_train_TP+1:n_train_TP+n_test_TP);
TP_val = segment_TP(:,:,n_train_TP+n_test_TP+1:end);

% combine to X and y
X_train = cat(3,TN_train, TP_train);
y_train = [(repmat([2],1,n_train_TN)),(repmat([1],1,n_train_TP))];

X_test= cat(3,TN_test, TP_test);
y_test= [(repmat([2],1,n_test_TN)),(repmat([1],1,n_test_TP))];

X_val = cat(3,TN_val, TP_val);
y_val = [(repmat([2],1,n_test_TN)),(repmat([1],1,n_test_TP))];

%% retraining the network
load('convnet.mat')
layers = convnet.Layers;

%{
X_train = reshape(X_train, size(X_train,1), size(X_train,2), 1, size(X_train,3));
y_train = categorical(y_train);

X_val = reshape(X_val, size(X_val,1), size(X_val,2), 1, size(X_val,3));
y_val = categorical(y_val);
%}

options = trainingOptions('sgdm', ...
    'InitialLearnRate', 1e-3, ...   % gentle nudge, low LR
    'MaxEpochs', 5, ...
    'MiniBatchSize', 200, ...
    'Momentum', 0.9, ...
    'L2Regularization', 0.001, ...
    'ValidationData', {X_val, y_val}, ...
    'ValidationFrequency', 50, ...
    'Plots','training-progress');

net = trainNetwork(X_train, y_train, layers, options);