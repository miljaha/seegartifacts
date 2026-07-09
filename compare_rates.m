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

%% load the detection rates

All_channels = [];
All_bad = [];

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
end

%% compare Artefacts_removed and CNN-artefacts_removed
for b = 1:nBiomarkers
    col_man = All_channels{:,(bm-1)*3+2};     % Manual artefacts
    col_cnn = T.rates{:,(bm-1)*3+3};        % CNN artefacts removed
    
    
end