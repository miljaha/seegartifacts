function data = uni2bi_montage(dataraw, label)
%% Filters used channels from raw data, outputs usable data sruct

% INPUT
% dataraw: All data, including unused channels
% label: string array of the bipolar contacts 

% OUTPUT
% data: struct with field
%       data_lab_bip: List of the used channels
%       data.x_bip: Data from the used channels

%% Creates the data struct
disp('--- Applying bipolar montage to create the main data structure ---');
% Start timer
bipolar_time = tic;
% Get montage indices
[~, bipo_inds, ~] = bipolar_montage_indices(label);

%% Creates the data structure
data.lab_bip = string([char(label{bipo_inds(:,1)}) repelem('-',length(bipo_inds),1) char(label{bipo_inds(:,2)})]);
data.x_bip = dataraw(bipo_inds(:,1),:) - dataraw(bipo_inds(:,2),:);
% Filters out unnecessary labels
data.lab_bip = strrep(data.lab_bip,'EEG','');
data.lab_bip = strrep(data.lab_bip,' ','');
data.lab_bip = strrep(data.lab_bip,'-REF','');
data.lab_bip = strrep(data.lab_bip,'-Ref','');
% Log time spent
disp(['Bipolar montage took a total of ' num2str(round(toc(bipolar_time))) ' seconds']);
disp('--- Bipolar montage finished ---');

end