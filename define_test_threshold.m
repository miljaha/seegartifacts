%% Determine the threshold value for each subject and analyze its utility
patients = [12,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60];
n = length(patients);

I = repmat(1:n,n,1)';
testing_idx = I(logical(eye(n)));
training_idx = reshape(I(~eye(n)), n-1, n)';

for i = 10
    %% get the data from one sub
    loadfilename = "subj" + string(patients(i));
    loadadress = '/projects3/EPIHFO/EPIHFO/seegartifacts/LOSO/trainingval_'+loadfilename+'.mat';
    load(loadadress);

    xvals = 0:0.01:1;
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
        BadChannels(data.badchans) = true;
        
        [X,Y,T] = perfcurve(BadChannels, data.channel_prob, true, 'XVals', xvals);
        [X_u, ia] = unique(X, 'last');
        Y = interp1(X_u, Y(ia), xvals, 'linear', 'extrap');
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
    [~, ind] = max(average_ROC .* (1-xvals));
    best_T_chan = mean(z_T_chan(:,ind)); % average threshold at the operating point

    % for artifacts
    average_ROC = mean(Y_seg,1);
    [~, ind] = max(average_ROC .* (1-xvals));
    best_T_seg = mean(z_T_seg(:,ind));
end