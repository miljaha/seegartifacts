clear; close all; clc;

%% Determine the threshold value for each subject and analyze its utility
patients = [12,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60];
n = length(patients);
I = repmat(1:n,n,1)';
testing_idx = I(logical(eye(n)));
validation_idx = reshape(I(~eye(n)), n-1, n)';

%% Main
xvals = [linspace(0,1,5000), Inf];
testing_sensitivity_ch = zeros(length(xvals),length(patients));
testing_specificity_ch = zeros(length(xvals),length(patients));
testing_precision_ch   = zeros(length(xvals),length(patients));
testing_recall_ch      = zeros(length(xvals),length(patients));
testing_sensitivity_sg = zeros(length(xvals),length(patients));
testing_specificity_sg = zeros(length(xvals),length(patients));
testing_precision_sg   = zeros(length(xvals),length(patients));
testing_recall_sg      = zeros(length(xvals),length(patients));
testing_roc_chan_op = zeros(length(patients),2);
testing_roc_time_op = zeros(length(patients),2);
testing_prc_chan_op = zeros(length(patients),2);
testing_prc_time_op = zeros(length(patients),2);
testing_roc_chan_op_true =  zeros(length(patients),2);
testing_prc_chan_op_true =  zeros(length(patients),2);
testing_roc_time_op_true =  zeros(length(patients),2);
testing_prc_time_op_true =  zeros(length(patients),2);
channel_thresh = zeros(1,length(patients));
segment_thresh = zeros(1,length(patients));

for i = [1,10] % iterate through the subjects
    %% Get the training/validation subjects and compute performance
    loadfilename = "subj" + patients(i);
    loadadress = "trainingval_" + loadfilename + ".mat";
    load(loadadress);
    idx = 0;
    validation_chan_mask = cell(1,length(patients(validation_idx(i,:))));
    validation_time_mask = cell(1,length(patients(validation_idx(i,:))));
    validation_chan_prob = cell(1,length(patients(validation_idx(i,:))));
    validation_time_prob = cell(1,length(patients(validation_idx(i,:))));
    validation_sensitivity_ch = zeros(length(xvals),length(patients(validation_idx(i,:))));
    validation_specificity_ch = zeros(length(xvals),length(patients(validation_idx(i,:))));
    validation_precision_ch   = zeros(length(xvals),length(patients(validation_idx(i,:))));
    validation_recall_ch      = zeros(length(xvals),length(patients(validation_idx(i,:))));
    validation_sensitivity_sg = zeros(length(xvals),length(patients(validation_idx(i,:))));
    validation_specificity_sg = zeros(length(xvals),length(patients(validation_idx(i,:))));
    validation_precision_sg   = zeros(length(xvals),length(patients(validation_idx(i,:))));
    validation_recall_sg      = zeros(length(xvals),length(patients(validation_idx(i,:))));

    for j = patients(validation_idx(i,:))
        idx = idx + 1;
        fieldname = 'Pat' + string(j);
        data = trainingval_res.(fieldname);

        %%% Get true labels and predicted probabilities
        % True bad channel mask
        validation_chan_mask{idx} = false(size(data.channel_prob));
        validation_chan_mask{idx}(data.badchans) = true; % manually marked
        % True artifact mask
        nSegments = size(data.time_prob,2);
        artefact_segments = data.artifacts;
        validation_time_mask{idx} = false(1, nSegments);
        for a = 1:size(artefact_segments,1)
            startSeg = max(floor(artefact_segments(a,1)/3)+1, 1);
            endSeg = min(ceil(artefact_segments(a,2)/3), nSegments);
            validation_time_mask{idx}(startSeg:endSeg) = true;
        end
        % Prediction probabilities
        validation_chan_prob{idx} = data.channel_prob;
        validation_time_prob{idx} = data.time_prob;

        %%% Calculate validation performance
        for p = 1:length(xvals)
            threshold = xvals(p);%*std(validation_chan_prob{idx}) + mean(validation_chan_prob{idx});
            temp = validation_chan_prob{idx} >= threshold;
            validation_sensitivity_ch(p,idx) = sum(validation_chan_mask{idx} & temp) / sum(validation_chan_mask{idx});
            validation_specificity_ch(p,idx) = sum(~validation_chan_mask{idx} & ~temp) / sum(~validation_chan_mask{idx});
            if sum(temp) == 0, validation_precision_ch(p,idx) = 1;
            else, validation_precision_ch(p,idx) = sum(validation_chan_mask{idx} & temp) / sum(temp); end
            validation_recall_ch(p,idx) = validation_sensitivity_ch(p,idx);
            temp = validation_time_prob{idx} >= threshold;
            validation_sensitivity_sg(p,idx) = sum(validation_time_mask{idx} & temp) / sum(validation_time_mask{idx});
            validation_specificity_sg(p,idx) = sum(~validation_time_mask{idx} & ~temp) / sum(~validation_time_mask{idx});
            if sum(temp) == 0, validation_precision_sg(p,idx) = 1;
            else, validation_precision_sg(p,idx) = sum(validation_time_mask{idx} & temp) / sum(temp); end
            validation_recall_sg(p,idx) = validation_sensitivity_sg(p,idx);
        end
    end

    %% Find best probability threshold
    perf_chan = mean((validation_sensitivity_ch + validation_specificity_ch)./2,2);
    [~, channelIdx] = max(perf_chan);
    channel_thresh(i) = xvals(channelIdx);
    validation_roc_chan_op = [1-validation_specificity_ch(channelIdx,:); validation_sensitivity_ch(channelIdx,:)];
    validation_prc_chan_op = [validation_recall_ch(channelIdx,:); validation_precision_ch(channelIdx,:)];

    perf_time = mean((validation_sensitivity_sg + validation_specificity_sg)./2,2);
    [~, segmentIdx] = max(perf_time);
    segment_thresh(i) = xvals(segmentIdx);
    validation_roc_time_op = [1-validation_specificity_sg(segmentIdx,:); validation_sensitivity_sg(segmentIdx,:)];
    validation_prc_time_op = [validation_recall_sg(segmentIdx,:); validation_precision_sg(segmentIdx,:)];

    %% Get the testing subject
    loadadress = "probabilitymap_Pat"+ patients(i) + "_results_sleeptimes.mat";
    load(loadadress);
    %%% True bad channel mask
    testing_chan_mask = results.badchannels;
    %%% True artifact mask
    nSegments = size(results.map,2);
    artefact_segments = results.artefacts;
    testing_time_mask = false(1, nSegments);
    for a = 1:size(artefact_segments,1)
        startSeg = max(floor(artefact_segments(a,1)/3)+1, 1);
        endSeg = min(ceil(artefact_segments(a,2)/3), nSegments);
        testing_time_mask(startSeg:endSeg) = true;
    end
    %%% Prediction probabilities
    testing_chan_prob = mean(results.map,2);
    testing_time_prob = mean(results.map,1);

    %%% Calculate testing performance
    for p = 1:length(xvals)
        temp = testing_chan_prob >= xvals(p);
        testing_sensitivity_ch(p,i) = sum(testing_chan_mask & temp) / sum(testing_chan_mask);
        testing_specificity_ch(p,i) = sum(~testing_chan_mask & ~temp) / sum(~testing_chan_mask);
        if sum(temp) == 0, testing_precision_ch(p,i) = 1;
        else, testing_precision_ch(p,i) = sum(testing_chan_mask & temp) / sum(temp); end
        testing_recall_ch(p,i) = testing_sensitivity_ch(p,i);
        temp = testing_time_prob >= xvals(p);
        testing_sensitivity_sg(p,i) = sum(testing_time_mask & temp) / sum(testing_time_mask);
        testing_specificity_sg(p,i) = sum(~testing_time_mask & ~temp) / sum(~testing_time_mask);
        if sum(temp) == 0, testing_precision_sg(p,i) = 1;
        else, testing_precision_sg(p,i) = sum(testing_time_mask & temp) / sum(temp); end
        testing_recall_sg(p,i) = testing_sensitivity_sg(p,i);
    end

    %%% Apply the probability threshold
    testing_roc_chan_op(i,:) = [1-testing_specificity_ch(channelIdx,i), testing_sensitivity_ch(channelIdx,i)];
    testing_roc_time_op(i,:) = [1-testing_specificity_sg(segmentIdx,i), testing_sensitivity_sg(segmentIdx,i)];
    testing_prc_chan_op(i,:) = [testing_recall_ch(channelIdx,i), testing_precision_ch(channelIdx,i)];
    testing_prc_time_op(i,:) = [testing_recall_sg(segmentIdx,i), testing_precision_sg(segmentIdx,i)];

    %%%% Find the "true" best threshold (Milja)
    perf_chan = mean((testing_sensitivity_ch + testing_specificity_ch)./2,2);
    [~, channelIdx] = max(perf_chan);
    testing_roc_chan_op_true(i,:) = [1-testing_specificity_ch(channelIdx,i), testing_sensitivity_ch(channelIdx,i)];
    testing_prc_chan_op_true(i,:) = [testing_recall_ch(channelIdx,i), testing_precision_ch(channelIdx,i)];

    perf_time = mean((testing_sensitivity_sg + testing_specificity_sg)./2,2);
    [~, segmentIdx] = max(perf_time);
    testing_roc_time_op_true(i,:) = [1-testing_specificity_sg(segmentIdx,i), testing_sensitivity_sg(segmentIdx,i)];
    testing_prc_time_op_true(i,:) = [testing_recall_sg(segmentIdx,i), testing_precision_sg(segmentIdx,i)];

    %% Plotting
    figure("Color","w");
    subplot(1,2,1);
    plot(1-validation_specificity_ch, validation_sensitivity_ch,'Color',[0.7 0.7 0.7]); hold on;
    h1 = plot(mean(1-validation_specificity_ch,2), mean(validation_sensitivity_ch,2),'k','LineWidth',3);
    h2 = scatter(mean(validation_roc_chan_op(1,:),2),mean(validation_roc_chan_op(2,:),2), ...
        'MarkerFaceColor','r','Marker','o','MarkerEdgeColor','r','LineWidth',2);
    h3 = plot(1-testing_specificity_ch(:,i), testing_sensitivity_ch(:,i),'linewidth',3,"Color",[0.15,0.55,0.87]); hold on;
    h4 = scatter(testing_roc_chan_op(i,1),testing_roc_chan_op(i,2),'MarkerFaceColor','r', ...
        'Marker','^','MarkerEdgeColor','r','LineWidth',2); grid on;   
    h5 = scatter(testing_roc_chan_op_true(i,1),testing_roc_chan_op_true(i,2),'MarkerFaceColor','r', ...
        'Marker','s','MarkerEdgeColor','r','LineWidth',2);
    xlabel("1 - Specificity","FontSize",14,"Interpreter","latex");
    ylabel("Sensitivity","FontSize",14,"Interpreter","latex");
    legend([h1,h3(1),h2,h4,h5],"Averaged Validation ROC (AUC = " + ...
        round(averaged_auc(mean(1-validation_specificity_ch,2), ...
        mean(validation_sensitivity_ch,2)),3) + ")", "Testing ROC (AUC = " ...
        + round(averaged_auc(1-testing_specificity_ch(:,i), ...
        testing_sensitivity_ch(:,i)),3)+ ")","Validation Operating Point", ...
        "Testing Operating Point","True Testing Operating Point","Location","southeast");
    subplot(1,2,2);
    plot(validation_recall_ch, validation_precision_ch,'Color',[0.7 0.7 0.7]); hold on;
    h1 = plot(mean(validation_recall_ch,2), mean(validation_precision_ch,2),'k','LineWidth',3);
    h2 = scatter(mean(validation_prc_chan_op(1,:),2),mean(validation_prc_chan_op(2,:),2), ...
        'MarkerFaceColor','r','Marker','o','MarkerEdgeColor','r','LineWidth',2);
    h3 = plot(testing_recall_ch(:,i), testing_precision_ch(:,i),'linewidth',3,"Color",[0.15,0.55,0.87]); hold on;
    h4 = scatter(testing_prc_chan_op(i,1),testing_prc_chan_op(i,2),'MarkerFaceColor','r', ...
        'Marker','^','MarkerEdgeColor','r','LineWidth',2); grid on;
    h5 = scatter(testing_prc_chan_op_true(i,1),testing_prc_chan_op_true(i,2),'MarkerFaceColor','r', ...
        'Marker','s','MarkerEdgeColor','r','LineWidth',2); grid on;   
    xlabel("Recall","FontSize",14,"Interpreter","latex");
    ylabel("Precision","FontSize",14,"Interpreter","latex");
    legend([h1,h3(1),h2,h4,h5],"Averaged Validation PRC (AUC = " + ...
        round(averaged_auc(mean(validation_recall_ch,2), ...
        mean(validation_precision_ch,2)),3) + ")", "Testing PRC (AUC = " ...
        + round(averaged_auc(testing_recall_ch(:,i), ...
        testing_precision_ch(:,i)),3)+ ")","Validation Operating Point", ...
        "Testing Operating Point","True Testing Operating Point","Location","southwest");
    sgtitle("Bad Channel Detection (Subject " + patients(i) + ")", ...
        "FontSize",18,"Interpreter","latex");

    figure("Color","w");
    subplot(1,2,1);
    plot(1-validation_specificity_sg, validation_sensitivity_sg,'Color',[0.7 0.7 0.7]); hold on;
    h1 = plot(mean(1-validation_specificity_sg,2), mean(validation_sensitivity_sg,2),'k','LineWidth',3);
    h2 = scatter(mean(validation_roc_time_op(1,:),2),mean(validation_roc_time_op(2,:),2), ...
        'MarkerFaceColor','r','Marker','o','MarkerEdgeColor','r','LineWidth',2);
    h3 = plot(1-testing_specificity_sg(:,i), testing_sensitivity_sg(:,i),'linewidth',3,"Color",[0.15,0.55,0.87]); hold on;
    h4 = scatter(testing_roc_time_op(i,1),testing_roc_time_op(i,2),'MarkerFaceColor','r', ...
        'Marker','^','MarkerEdgeColor','r','LineWidth',2); grid on;
    h5 = scatter(testing_roc_time_op_true(i,1),testing_roc_time_op_true(i,2),'MarkerFaceColor','r', ...
        'Marker','s','MarkerEdgeColor','r','LineWidth',2);
    xlabel("1 - Specificity","FontSize",14,"Interpreter","latex");
    ylabel("Sensitivity","FontSize",14,"Interpreter","latex");
    legend([h1,h3(1),h2,h4,h5],"Averaged Validation ROC (AUC = " + ...
        round(averaged_auc(mean(1-validation_specificity_sg,2), ...
        mean(validation_sensitivity_sg,2)),3) + ")", "Testing ROC (AUC = " ...
        + round(averaged_auc(1-testing_specificity_sg(:,i), ...
        testing_sensitivity_sg(:,i)),3)+ ")","Validation Operating Point", ...
        "Testing Operating Point","True Testing Operating Point","Location","southeast");
    subplot(1,2,2);
    plot(validation_recall_sg, validation_precision_sg,'Color',[0.7 0.7 0.7]); hold on;
    h1 = plot(mean(validation_recall_sg,2), mean(validation_precision_sg,2),'k','LineWidth',3);
    h2 = scatter(mean(validation_prc_time_op(1,:),2),mean(validation_prc_time_op(2,:),2), ...
        'MarkerFaceColor','r','Marker','o','MarkerEdgeColor','r','LineWidth',2);
    h3 = plot(testing_recall_sg(:,i), testing_precision_sg(:,i),'linewidth',3,"Color",[0.15,0.55,0.87]); hold on;
    h4 = scatter(testing_prc_time_op(i,1),testing_prc_time_op(i,2),'MarkerFaceColor','r', ...
        'Marker','^','MarkerEdgeColor','r','LineWidth',2); grid on;
    h5 = scatter(testing_prc_time_op_true(i,1),testing_prc_time_op_true(i,2),'MarkerFaceColor','r', ...
        'Marker','s','MarkerEdgeColor','r','LineWidth',2); grid on;
    xlabel("Recall","FontSize",14,"Interpreter","latex");
    ylabel("Precision","FontSize",14,"Interpreter","latex");    
    legend([h1,h3(1),h2,h4,h4],"Averaged Validation PRC (AUC = " + ...
        round(averaged_auc(mean(validation_recall_sg,2), ...
        mean(validation_precision_sg,2)),3) + ")", "Testing PRC (AUC = " ...
        + round(averaged_auc(testing_recall_sg(:,i), ...
        testing_precision_sg(:,i)),3)+ ")","Validation Operating Point", ...
        "Testing Operating Point","True Testing Operating Point","Location","southwest");  
    sgtitle("Artefact Detection (Subject " + patients(i) + ")", ...
        "FontSize",18,"Interpreter","latex");
end

function auc = averaged_auc(x,y)
x = x(:);
y = y(:);
auc = trapz(flip(x), flip(y));
end