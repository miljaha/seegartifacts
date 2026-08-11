%% Split data into training & testing & validation sets using 80/20/20 ratio

% number of samples to each group
n_train_TN = ceil(size(segment_TN,3)*0.8);
n_test_TN = (size(segment_TN,3)-n_train_TN)*0.5;

n_train_TP = ceil(size(segment_TP,3)*0.8);
n_test_TP = (size(segment_TP,3)-n_train_TP)*0.5; % = n_val

n_train_path = n_train_TN / 2;
n_test_path = n_test_TN / 2;

% shuffle segments and pick the samples
segment_TN = segment_TN(:,:,randperm(size(segment_TN,3)));
TN_train = segment_TN(:,:,1:n_train_TN);
TN_test = segment_TN(:,:,n_train_TN+1:n_train_TN+n_test_TN);
TN_val = segment_TN(:,:,n_train_TN+n_test_TN+1:end);

segment_TP = segment_TP(:,:,randperm(size(segment_TP,3)));
TP_train = segment_TP(:,:,1:n_train_TP);
TP_test = segment_TP(:,:,n_train_TP+1:n_train_TP+n_test_TP);
TP_val = segment_TP(:,:,n_train_TP+n_test_TP+1:end);

segment_path = segment_pathology(:,:,randperm(size(segment_pathology,3)));
pathology_train = segment_pathology(:,:,1:n_train_path);
pathology_test = segment_pathology(:,:,n_train_path+1:n_train_path+n_test_path);
pathology_val = segment_pathology(:,:,n_train_path+n_test_path+1:end);

% combine to X and y
X_train = cat(3,TN_train, TP_train, pathology_train);
y_train = [(repmat([2],1,n_train_TN)),(repmat([1],1,n_train_TP)),(repmat([3],1,n_train_path))];

X_test= cat(3,TN_test, TP_test, pathology_test);
y_test= [(repmat([2],1,n_test_TN)),(repmat([1],1,n_test_TP)),(repmat([3],1,n_test_path))];

X_val = cat(3,TN_val, TP_val, pathology_val);
y_val = [(repmat([2],1,n_test_TN)),(repmat([1],1,n_test_TP)),(repmat([3],1,n_test_path))];

% retraining the network
load('convnet.mat')
layers = convnet.Layers;

% shape the samples and labels
X_train = reshape(X_train, size(X_train,1), size(X_train,2), 1, size(X_train,3));
y_train = categorical(y_train, [1 2 3], {'noise','ok','patology'});

X_val = reshape(X_val, size(X_val,1), size(X_val,2), 1, size(X_val,3));
y_val = categorical(y_val, [1 2 3], {'noise','ok','patology'});

options = trainingOptions('sgdm', ...
    'InitialLearnRate', 1e-5, ...   % gentle nudge, low LR
    'MaxEpochs', 30, ...
    'MiniBatchSize', 32, ...
    'Momentum', 0.9, ...
    'L2Regularization', 0.001, ...
    'ValidationData', {X_val, y_val}, ...
    'ValidationFrequency', 50, ...
    'ValidationPatience',5,...
    'Plots','training-progress');

net = trainNetwork(X_train, y_train, layers, options);

%
X_test = reshape(X_test, size(X_test,1), size(X_test,2), 1, size(X_test,3));
y_test = categorical(y_test, [1 2 3], {'noise','ok','patology'});


YPredBefore = classify(convnet, X_test);            % original network
YPredAfter = classify(net, X_test);     % fine-tuned network

confusionmat(y_test, YPredBefore)
confusionmat(y_test, YPredAfter)

%
classNames = {'noise','ok','patology'};
%
figure % confusion matrices
subplot(1,2,1)
cm = confusionchart(y_test, YPredBefore, ...
    'RowSummary','row-normalized', ...      % shows recall per class on the side
    'ColumnSummary','column-normalized', ... % shows precision per class on bottom
    'Title','Before retraining');
subplot(1,2,2)
cm = confusionchart(y_test, YPredAfter, ...
    'RowSummary','row-normalized', ...      % shows recall per class on the side
    'ColumnSummary','column-normalized', ... % shows precision per class on bottom
    'Title','After retraining');

% summary table
C_before = confusionmat(y_test, YPredBefore);
C_after  = confusionmat(y_test, YPredAfter);

precisionBefore = diag(C_before) ./ sum(C_before,1)';
recallBefore    = diag(C_before) ./ sum(C_before,2);
f1Before        = 2 * (precisionBefore .* recallBefore) ./ (precisionBefore + recallBefore);

precisionAfter = diag(C_after) ./ sum(C_after,1)';
recallAfter    = diag(C_after) ./ sum(C_after,2);
f1After        = 2 * (precisionAfter .* recallAfter) ./ (precisionAfter + recallAfter);

comparisonTable = table(classNames', ...
    precisionBefore, precisionAfter, precisionAfter - precisionBefore, ...
    recallBefore, recallAfter, recallAfter - recallBefore, ...
    f1Before, f1After, f1After - f1Before, ...
    'VariableNames', {'Class', ...
        'Precision_Before','Precision_After','Precision_Delta', ...
        'Recall_Before','Recall_After','Recall_Delta', ...
        'F1_Before','F1_After','F1_Delta'})