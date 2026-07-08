function CNN_excluded = exclude_CNN(biomarkers, CNN_matrix, sample_window, idx,fs)

    recording_start = sample_window(1,idx);
    CNN_excluded = [];
    counter = 1;

    for i = 1:size(biomarkers, 1)
        start_sample = biomarkers(i,3) - recording_start;
        chan = biomarkers(i,1);
        segmentIndex = min(floor(start_sample / (3*fs))+1,size(CNN_matrix,1));
        if CNN_matrix(segmentIndex,chan) == 0
            CNN_excluded(counter,:) = biomarkers(i,:);
            counter = counter + 1;
        end
    end
    n_excluded = size(biomarkers,1) - size(CNN_excluded,1);
    fprintf("%d samples excluded using CNN artifacts\n", n_excluded);