nets = load('/net/sigma/fishpool3/projects3/EPIHFO/EPIHFO/seegartifacts/LOSO/LOSO_results.mat');
patients = [12,19,20,21,22,23,24,25,26,28,27,29,30,31,32,33,34,35,36,37,38,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60];

for i = 1:length(patients)
    subj_num = patients(i);
    convnet = nets.results{i}.net;

    data_dir = "/projects3/EPIHFO/EPIHFO/Pat" + string(subj_num);
    [CNN_probabilities, epilept_probs, artifact_samples_all, bad_chan_idx] = read_and_classify_data(subj_num, data_dir);

    plot_probabilitites(CNN_probabilities, artifact_samples_all, bad_chan_idx,subj_num)
end
