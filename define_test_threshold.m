%% Determine the threshold value for each subject and analyze its utility
patients = [12,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60];
n = length(patients);

I = repmat(1:n,n,1)';
testing_idx = I(logical(eye(n)));
training_idx = reshape(I(~eye(n)), n-1, n)';


thresholding_results = struct();
for i = [1,10]
    %% get the data from one sub
    loadfilename = "subj" + string(patients(i));
    loadadress = '/projects3/EPIHFO/EPIHFO/seegartifacts/LOSO/trainingval_'+loadfilename+'.mat';
    load(loadadress);

    xvals = 0:0.01:1; % even length roc curves
    Y_chan = zeros(n-1,length(xvals));
    z_T_chan =zeros(size(Y_chan));

    Y_seg = zeros(size(Y_chan));
    z_T_seg = zeros(size(Y_chan));

    idx = 0;
    for j = patients(training_idx(i,:))
        idx = idx + 1;
        fieldname = 'Pat'+string(j);
        data = trainingval_res.(fieldname);

        %% Bad channel predictions
        BadChannels = false(size(data.channel_prob));
        BadChannels(data.badchans) = true; % manually marked
        
        [X,Y,T] = perfcurve(BadChannels, data.channel_prob, true, 'XVals', xvals);
        [X_u, ia] = unique(X, 'last');
        Y = interp1(X_u, Y(ia), xvals, 'linear', 'extrap'); % even lengths
        T = interp1(X_u, T(ia), xvals, 'linear', 'extrap');
        z_T = (T - mean(data.channel_prob)) / std(data.channel_prob);
        Y_chan(idx,:) = Y;
        z_T_chan(idx,:) = z_T;

        %% Artifact time predictions
        nSegments = size(data.time_prob,2);
        artefact_segments = data.artifacts;
        artefact_vec = zeros(1, nSegments);

        for a = 1:size(artefact_segments,1)
            startSeg = max(floor(artefact_segments(a,1)/3)+1, 1);
            endSeg = min(ceil(artefact_segments(a,2)/3), nSegments);
            artefact_vec(startSeg:endSeg) = 1;
        end

        [X,Y,T] = perfcurve(artefact_vec, data.time_prob, 1, 'XVals', xvals);
        [X_u, ia] = unique(X, 'last');
        Y = interp1(X_u, Y(ia), xvals, 'linear', 'extrap');
        T = interp1(X_u, T(ia), xvals, 'linear', 'extrap');
        z_T = (T - mean(data.time_prob)) / std(data.time_prob);
        Y_seg(idx,:) = Y;
        z_T_seg(idx,:) = z_T;
    end
    %% average over trials to find the best threshold / operating point
    % for channels
    average_ROC = mean(Y_chan,1);
    [~, ind] = max(average_ROC .* (1-xvals)); % operating point frin averaged ROCs
    best_T_chan = mean(z_T_chan(:,ind)); % average threshold at the operating point

    % for artifacts
    average_ROC = mean(Y_seg,1);
    [~, ind] = max(average_ROC .* (1-xvals));
    best_T_seg = mean(z_T_seg(:,ind));

    %% test the defined thresholds
    pathname = '/projects3/EPIHFO/EPIHFO/seegartifacts/LOSO/probabilitymap_Pat'+string(patients(i))+'_results_sleeptimes.mat';
    load(pathname)
    fieldname = 'Pat'+string(patients(i));
    % for channels
    channel_prob = mean(results.map,2);
    threshold = mean(channel_prob) + best_T_chan*std(channel_prob);
    badchan_peaks = channel_prob > threshold;

    badchannels = results.badchannels;

    TP = sum(badchannels & badchan_peaks);
    FP = sum(~badchannels & badchan_peaks);
    FN = sum(badchannels & ~badchan_peaks);
    TN = sum(~badchannels & ~badchan_peaks);

    acc  = (TP+TN)/(TP+FP+TN+FN);   % <- fixed, see below
    ppv  = TP/(TP+FP);
    spec = TN/(TN+FP);
    sens = TP/(TP+FN);
    F1   = 2*(ppv*sens) / (ppv+sens);
    thresholding_results.(fieldname).channels = {"Accuracy","PPV","Specificity","Sensitivity", "F1","T";...
                                                acc ,ppv, spec, sens, F1, best_T_chan};
    
    % for artifact time
    artifact_prob = mean(results.map,1);
    threshold = mean(artifact_prob) + best_T_seg*std(artifact_prob);

    nSegments = size(results.map,2);
    artefact_segments = results.artefacts;
    artefact_vec = zeros(1, nSegments);
    for a = 1:size(artefact_segments,1)
        startSeg = max(floor(artefact_segments(a,1)/3)+1, 1);
        endSeg = min(ceil(artefact_segments(a,2)/3), nSegments);
        artefact_vec(startSeg:endSeg) = 1;
    end

    artefact_peaks = artifact_prob > threshold;
        
    TP = sum(artefact_vec & artefact_peaks);
    FP = sum(~artefact_vec & artefact_peaks);
    FN = sum(artefact_vec & ~artefact_peaks);
    TN = sum(~artefact_vec & ~artefact_peaks);

    acc = (TP+TN)/(TP+FP+TN+FN);
    ppv  = TP/(TP+FP);
    spec = TN/(TN+FP);
    sens = TP/(TP+FN);
    F1   = 2*(ppv*sens) / (ppv+sens);
    thresholding_results.(fieldname).artifacts = {"Accuracy","PPV","Specificity","Sensitivity", "F1","T";...
                                                 acc ,ppv, spec, sens, F1, best_T_seg};


end