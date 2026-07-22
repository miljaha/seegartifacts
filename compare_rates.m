%% define variables

subj_nums = [12,19,20,21,22,23,24,25,26,27,28,29,30,31,...
32,33,34,35,36,37,38,40,41,42,43,44,45,46,47,48];%,50,52,53,56,58,59,60];         % Subject numbers

sub_block = {'Original','Manual','CNN'};
sub_hdr = [{'Channel number','Label','Bad channel','Duration after CNN'} repmat(sub_block, 1, 12)];

main_hdr = {'FR rate (1/min)', '', '';...
            'R rate (1/min)', '', '';...
            'IED rate (1/min)', '', '';...
            'SFR rate (1/min)', '', '';...
            'SRipple rate (1/min)', '', '';...
            'GS rate (1/min)', '', '';...

            'FR occupancy (%)', '', '';...
            'R occupancy (%)', '', '';...
            'IED occupancy (%)', '', '';...
            'SFR occupancy (%)', '', '';...
            'SRipple occupancy (%)', '', '';...
            'GS occupancy (%)', '', ''};
        
  
nMetrics = 3;
biomarkers = main_hdr(~cellfun(@isempty, main_hdr))';
biomarkers = biomarkers(1:6);
nBiomarkers = length(biomarkers);
nSubjects = length(subj_nums);
nBoot = 10000;

%% load the detection rates

All_channels = [];  % rates
All_bad = [];       % bad channels 0/1
subj_idx = [];      % subject number
valid_subjs = [];

for i = 1:nSubjects
    % load data
    try
        filename = "/projects3/EPIHFO/EPIHFO/Pat" + string(subj_nums(i)) + "/detection_rates_pat"+string(subj_nums(i))+".xls";
        T.info = readtable(filename, "Sheet", "files combined","Range","A1:B7",'VariableNamingRule','preserve');
        T.rates = readtable(filename, "Sheet", "files combined", "Range","A9",'VariableNamingRule','preserve');
        T.badchannels = readtable(filename,"Sheet", "files combined", "Range","C11:C200",'VariableNamingRule','preserve');
        T.badchannels = T.badchannels(~isnan(table2array(T.badchannels)),1);
        
        % ignore occupancies
        T.rates = T.rates(:,6:5+nMetrics*nBiomarkers); 
        
        % gather information
        All_patients.("Pat"+string(subj_nums(i))) = T;
        All_channels = [All_channels; T.rates];
        All_bad = [All_bad; table2array(T.badchannels)];
        subj_idx = [subj_idx; repmat(subj_nums(i),size(T.rates,1),1)];

        valid_subjs = [valid_subjs, subj_nums(i)];
    catch ME
        fprintf("Problem in reading data from subject %d, skipping this subject\n", subj_nums(i))
    end
end
nValid = length(valid_subjs);
%% compare Artefacts_removed and CNN-artefacts_removed
p_values = cell(nBiomarkers,2);
results = cell(nBiomarkers,5);
results_patients = cell(nValid+1, nBiomarkers+1);
results_patients(2:nValid+1,1) = num2cell(valid_subjs);
results_patients(1,2:nBiomarkers+1) = biomarkers;
difference = results_patients;
quotas = zeros(nBiomarkers,1);
diffs_all = [];
for b = 1:nBiomarkers
    col_man = All_channels{:,(b-1)*3+2};     % Manual artefacts
    col_cnn = All_channels{:,(b-1)*3+3};        % CNN artef acts removed
    
    diff = col_man - col_cnn; % calculate difference
    diffs_all = [diffs_all, diff];
    % how often is the difference over 5 %?
    perc = col_cnn ./ col_man;
    under5p = sum(perc >= 0.90 & perc <= 1.1);
    quotas(b) = under5p ./ length(col_man) * 100;
    medians = zeros(nValid,1);

    % equivalence test TOST
    delta1 = 0.05*mean(col_man,'omitnan'); % meaningless margin: 5% of the mean rate
    delta2 = 0.1*mean(col_man,'omitnan'); % 10%

    ci_level = 1 - 2*0.05; % confidance interval
    lower_pct = (1 - ci_level)/2 * 100;
    upper_pct = (1 - (1 - ci_level)/2) * 100;
    ci = prctile(diff, [lower_pct, upper_pct]);

    for p = 1:length(valid_subjs)
        medians(p) = median(diff(subj_idx == valid_subjs(p)));

        subj_all = diff(subj_idx == valid_subjs(p)); 
        results_patients{p+1,b+1} = (ci(1) > -delta2) && (ci(2) < delta2);
        difference{p+1,b+1} = median(col_cnn(subj_idx == valid_subjs(p)) ./ col_man(subj_idx == valid_subjs(p)))*100;
    end

    % p-value: small = difference, big = no difference detected (not proof
    % they're equal)
    p_values{b,2} = signrank(col_man, col_cnn);
    p_values(b,1) = biomarkers(b);

    is_equivalent1 = (ci(1) > -delta1) && (ci(2) < delta1);  % does the difference belong in 1st interval
    is_equivalent2 = (ci(1) > -delta2) && (ci(2) < delta2);
    
    results(b,:) = {biomarkers(b), median(diff,'omitnan'), ci, is_equivalent1, is_equivalent2};
end

%% plot histograms of differences
nChannels = size(diffs_all,1);
figure;
for i = 1:nBiomarkers
    subplot(3,2,i);
    edges = -10.1:0.2:10.1;
    histogram(diffs_all(:,i),'BinEdges',edges);
    title(biomarkers(i));
    xlabel('Difference');
    ylabel('Count');
    xlim([-10,10]);
end