%% define variables

subj_nums = [12,19];%,19,20,21,22,23,24,25,26,27,28,29,30,31,...
%32,33,34,35,36,37,38,40,41,42,43,44,45,46,47,48,49,50,52,53,56,58,59,60];         % Subject numbers

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

for i = 1:nSubjects
    % load data
    filename = "/projects3/EPIHFO/EPIHFO/Pat" + string(subj_nums(i)) + "/detection_rates_pat"+string(subj_nums(i))+".xls";
    T.info = readtable(filename, "Sheet", "files combined","Range","A1:B7",'VariableNamingRule','preserve');
    T.rates = readtable(filename, "Sheet", "files combined", "Range","A9",'VariableNamingRule','preserve');
    T.badchannels = readtable(filename,"Sheet", "files combined", "Range","C11:C200",'VariableNamingRule','preserve');
    T.badchannels = T.badchannels(~isnan(table2array(T.badchannels)),1);
    
    % ignore occupancies
    T.rates = T.rates(:,5:4+nMetrics*nBiomarkers); 
    
    % gather information
    All_patients.("Pat"+string(subj_nums(i))) = T;
    All_channels = [All_channels; T.rates];
    All_bad = [All_bad; table2array(T.badchannels)];
    subj_idx = [subj_idx; repmat(subj_nums(i),size(T.rates,1),1)];
end

%% compare Artefacts_removed and CNN-artefacts_removed
p_values = cell(nBiomarkers,2);
results = cell(nBiomarkers,5);


for b = 1:nBiomarkers
    col_man = All_channels{:,(b-1)*3+2};     % Manual artefacts
    col_cnn = All_channels{:,(b-1)*3+3};        % CNN artefacts removed
    
    diff = col_man - col_cnn; % calculate difference
    
    % p-value: small = difference, big = no difference detected (not proof
    % they're equal
    p_values{b,2} = signrank(col_man, col_cnn);
    p_values(b,1) = biomarkers(b);
    
    % equivalence test TOST
    delta1 = 0.05*mean(col_man); % meaningless margin: 5% of the mean rate
    delta2 = 0.1*mean(col_man); % 10%
    
    boot_medians = zeros(nBoot,1); 
    for i = 1:nBoot
        sample_subjs = subj_nums(randi(nSubjects,nSubjects,1)); % select random subjects
        boot_diffs = [];
        for p = 1:nSubjects
            boot_diffs = [boot_diffs; diff(subj_idx == sample_subjs(p))]; % get differences
        end
        boot_medians(i) = median(boot_diffs); % median of this bootstrapping round
    end

    ci_level = 1 - 2*0.05; % confidance interval
    lower_pct = (1 - ci_level)/2 * 100;
    upper_pct = (1 - (1 - ci_level)/2) * 100;
    ci = prctile(boot_medians, [lower_pct, upper_pct]);
    is_equivalent1 = (ci(1) > -delta1) && (ci(2) < delta1);  % does the difference belong in 1st interval
    is_equivalent2 = (ci(1) > -delta1) && (ci(2) < delta1);
    
    results(b,:) = {biomarkers(b), median(diff), ci, is_equivalent1, is_equivalent2};
    
end