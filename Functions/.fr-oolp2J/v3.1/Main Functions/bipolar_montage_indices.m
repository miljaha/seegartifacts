function [bipo_labels, bipo_inds, el_labels] = bipolar_montage_indices(label)
%% Updated on 20.5.2026 by Mohammad Al-Sa'd
%% Parses electrode labels into usable formats
% Creates a matrix for all electrode pairs and vectors for their labels,
% both by type and type-number combinations

% INPUT
% label: string array of the bipolar contacts 

% OUTPUT
% bipo_labels: string array of the bipolar contacts
% bipo_inds: Nbip x 2 to create bipolar labels from hdr.label
% el_labels: string array of the electrodes recognized (electrodes contain several contacts)

%% Create arrays
% bipol is a 2 row matrix, with the indexes to calculate the channels bipolar derivation.
% i.e. if label = {'EEG InA01-Ref','EEG InA02-Ref',....etc, then bipol(:,1) = [ 1; 2];

% disp('--- Attempting to create a bipolar montage for SEEG-data automatically ---');

% Create custom label and filter unnecessary labels
custom_labels=label;
custom_labels=custom_labels'; % pleonastic
custom_labels=strrep(custom_labels,'EEG','');
custom_labels=strrep(custom_labels,' ','');
custom_labels=strrep(custom_labels,'-REF','');
custom_labels=strrep(custom_labels,'-Ref','');

%% MA updated
exclude_prefixes = {'MKR','VALUEMKR','EKG','ECG',"EMG"};
keep = true(size(custom_labels));
for i = 1:numel(exclude_prefixes)
    keep = keep & ~startsWith(custom_labels, exclude_prefixes{i}, ...
        'IgnoreCase', true);
end
orig_inds = find(keep);
custom_labels = custom_labels(keep);

%%
% Loop through all custom labels and add them to the matrices
Nch = length(custom_labels);
bipo_inds=[]; bipo_labels={}; el_labels={};
for k = 1:Nch-1

    % Isolate text and number from contact name
    tmp1=custom_labels{k};              %fist electrode   
    tmp2=custom_labels{k+1};            %second electrode       
    
    % First value of the pair
    numinds=regexp(tmp1,'\d');
    if ~isempty(numinds)
        txt1=tmp1(1:numinds(1)-1);      %Pick text
        num1=tmp1(regexp(tmp1,'\d')); %Pick numbers
    else
        txt1=''; num1=[];
    end

    % Second value of the pair
    numinds=regexp(tmp2,'\d'); 
    if ~isempty(numinds)
        txt2=tmp2(1:numinds(1)-1);      %Pick text
        num2=tmp2(regexp(tmp2,'\d')); %Pick numbers
    else
        txt2=''; num2=[];
    end

    % Writes the electrode to matrices if it's in correct format
    if strcmpi(txt1,txt2) && str2double(num1)==str2double(num2)-1  % Same electrode and adjacent contact?                  
        bipo_labels = vertcat(bipo_labels,[tmp1 '-' tmp2]);        % New bipo label                 
        % bipo_inds = vertcat(bipo_inds, [k, k+1]);                  % Store all valid inds for bipo mtg
        bipo_inds = vertcat(bipo_inds, [orig_inds(k), orig_inds(k+1)]); %% MA updated
        el_labels = vertcat(el_labels, txt1);
    end    
end

% Filters out duplicates in el_labels data
el_labels=unique(el_labels,'stable');


end
