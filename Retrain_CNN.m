rng(67)

%% Split data into training & testing & validation sets using 80/10/10 ratio

% number of samples to each group
n_train_TN = 285;
n_test_TN = 35;

n_train_TP = 57;
n_test_TP = 7; % = n_val

n_train_extra = 285;
n_test_extra = 35;

% shuffle segments and pick the samples
segment_TN = segment_TN(:,:,randperm(size(segment_TN,3)));
TN_train = segment_TN(:,:,1:n_train_TN);
TN_test = segment_TN(:,:,n_train_TN+1:n_train_TN+n_test_TN);
TN_val = segment_TN(:,:,n_train_TN+n_test_TN+1:end);

segment_TP = segment_TP(:,:,randperm(size(segment_TP,3)));
TP_train = segment_TP(:,:,1:n_train_TP);
TP_test = segment_TP(:,:,n_train_TP+1:n_train_TP+n_test_TP);
TP_val = segment_TP(:,:,n_train_TP+n_test_TP+1:end);

segment_extra = segment_extra(:,:,randperm(size(segment_extra,3)));
extra_train = segment_extra(:,:,1:n_train_extra);
extra_test = segment_extra(:,:,n_train_extra+1:n_train_extra+n_test_extra);
extra_val = segment_extra(:,:,n_train_extra+n_test_extra+1:end);

% combine to X and y
% ADD EXTRA SAMPLES HERE!!!
X_train = cat(3,TN_train, TP_train, extra_train );
y_train = [(repmat([2],1,n_train_TN)),(repmat([1],1,n_train_TP)),repmat([2],1,n_train_extra),3];
y_train = categorical(y_train, [1 2 3], {'noise','ok','patology'});
y_train = y_train(1:end-1);

X_test= cat(3,TN_test, TP_test, extra_test);
y_test= [(repmat([2],1,n_test_TN)),(repmat([1],1,n_test_TP)),repmat([2],1,n_test_extra),3];
y_test = categorical(y_test, [1 2 3], {'noise','ok','patology'});
y_test = y_test(1:end-1);

X_val = cat(3,TN_val, TP_val, extra_val);
y_val = [(repmat([2],1,n_test_TN)),(repmat([1],1,n_test_TP)),repmat([2],1,n_test_extra),3];
y_val = categorical(y_val, [1 2 3], {'noise','ok','patology'});
y_val = y_val(1:end-1);

% shape the samples
X_train = reshape(X_train, size(X_train,1), size(X_train,2), 1, size(X_train,3));
X_val = reshape(X_val, size(X_val,1), size(X_val,2), 1, size(X_val,3));
X_test = reshape(X_test, size(X_test,1), size(X_test,2), 1, size(X_test,3));

% retraining the network
load('convnet.mat')
layers = convnet.Layers; % get original layers

options = trainingOptions('sgdm', ...
    'InitialLearnRate', 1e-5, ...   % gentle nudge, low LR
    'MaxEpochs', 30, ...
    'MiniBatchSize', 32, ...
    'Momentum', 0.9, ...
    'L2Regularization', 0.001, ...
    'ValidationData', {X_val, y_val}, ...
    'ValidationFrequency', 10, ...
    'ValidationPatience',5,...
    'Plots','training-progress');

% retraining
net = trainNetwork(X_train, y_train, layers, options);

% predictions before and after
YPredBefore = classify(convnet, X_test);            % original network
YPredAfter = classify(net2, X_test);     % fine-tuned network

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

save("retrained_network1","net")