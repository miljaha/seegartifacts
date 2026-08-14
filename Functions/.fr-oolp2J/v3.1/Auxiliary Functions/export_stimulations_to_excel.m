function export_stimulations_to_excel(excelfile, info, bipolar_channels, ...
    user_measure, Summary, exclude_bad_channel_mask, sample_window, fs, ...
    start_datetime, duration_original, duration_artefacts_removed)

% Get the codes for invalid entries
stimulation_channel_value = strsplit(info{7,1});
stimulation_channel_value = stimulation_channel_value(1);
neighbor_channel_value    = strsplit(info{8,1});
neighbor_channel_value    = neighbor_channel_value(1);
bad_channel_value         = strsplit(info{9,1});
bad_channel_value         = bad_channel_value(1);
num_stimulations          = info{6,1};

% Write the file/cycle information
sheet_name = string(erase(info{1,1},".edf"));
sheet_name = extractBetween(sheet_name, 1, min(strlength(sheet_name), 31)); % limit induced by excel sheet naming
writecell({'File:';'Time start:';'Time end:';'Stimulation frequency (Hz):'; ...
    'Stimulation current (mA):';'Number of stimulation cycles';'Notes'}, ...
    excelfile,'Sheet',sheet_name,'Range','A1');
writecell(info,excelfile,'Sheet',sheet_name,'Range','B1');

% Write the channel numbers and labels
writematrix((1:length(bipolar_channels))',excelfile,'Sheet',sheet_name,'Range','A12');
writematrix(bipolar_channels,excelfile,'Sheet',sheet_name,'Range','B12');

% Write column headers
user_measure = upper(user_measure);
main_hdr = repelem({""},1, 4*num_stimulations);
if strcmpi(user_measure,"s")
    main_hdr{1 + 0*num_stimulations} = "Original IED rate (1/sec)";
    main_hdr{1 + 1*num_stimulations} = "Artefacts removed IED rate (1/sec)";
    main_hdr{1 + 2*num_stimulations} = "Original IED occupancy (%)";
    main_hdr{1 + 3*num_stimulations} = "Artefacts removed IED occupancy (%)";
else
    main_hdr{1 + 0*num_stimulations} = "Original " + user_measure + " rate (1/sec)";
    main_hdr{1 + 1*num_stimulations} = "Artefacts removed " + user_measure + " rate (1/sec)";
    main_hdr{1 + 2*num_stimulations} = "Original " + user_measure + " occupancy (%)";
    main_hdr{1 + 3*num_stimulations} = "Artefacts removed " + user_measure + " occupancy (%)";
end
sub_hdr = {'Channel number','Channel label'};
writecell(main_hdr,excelfile,'Sheet',sheet_name,'Range','C10');
writecell(sub_hdr,excelfile,'Sheet',sheet_name,'Range','A11');
writecell({repmat("Cycle ",1,4*num_stimulations) + string(repmat(1:num_stimulations,1,4)) + ...
    ": " + repmat(Summary.stimulation_channel_label',1,4)}, excelfile, ...
    'Sheet',sheet_name,'Range',"C11");

% Write the measure rates and percentages of occupancy
switch lower(user_measure)
    case "r"
        temp = [[Summary.R_appear_rate_original{:}] [Summary.R_appear_rate_artefacts_removed{:}] [Summary.R_occupancy_rate_original{:}] [Summary.R_occupancy_rate_artefacts_removed{:}]];
    case "fr"
        temp = [[Summary.FR_appear_rate_original{:}] [Summary.FR_appear_rate_artefacts_removed{:}] [Summary.FR_occupancy_rate_original{:}] [Summary.FR_occupancy_rate_artefacts_removed{:}]];
    case "s"
        temp = [[Summary.IED_appear_rate_original{:}] [Summary.IED_appear_rate_artefacts_removed{:}] [Summary.IED_occupancy_rate_original{:}] [Summary.IED_occupancy_rate_artefacts_removed{:}]];
    case "sr"
        temp = [[Summary.SR_appear_rate_original{:}] [Summary.SR_appear_rate_artefacts_removed{:}] [Summary.SR_occupancy_rate_original{:}] [Summary.SR_occupancy_rate_artefacts_removed{:}]];
    case "sfr"
        temp = [[Summary.SFR_appear_rate_original{:}] [Summary.SFR_appear_rate_artefacts_removed{:}] [Summary.SFR_occupancy_rate_original{:}] [Summary.SFR_occupancy_rate_artefacts_removed{:}]];
    case "gs"
        temp = [[Summary.GS_appear_rate_original{:}] [Summary.GS_appear_rate_artefacts_removed{:}] [Summary.GS_occupancy_rate_original{:}] [Summary.GS_occupancy_rate_artefacts_removed{:}]];
end
writematrix(temp,excelfile,'Sheet',sheet_name,'Range',"C12");

% Insert codes for invalid entries
col_labels = excel_column_labels(2 + 4*num_stimulations);
col_labels = col_labels(3:end);

for stim_idx = 1:num_stimulations  % iterate through the stimulation cycles
    % "stimulation_channel_value" for the stimulation channels
    writecell({stimulation_channel_value},excelfile,'Sheet',sheet_name, ...
        'Range',col_labels(stim_idx + 0*num_stimulations) + string(11 + Summary.stimulation_channel_number(stim_idx)));
    writecell({stimulation_channel_value},excelfile,'Sheet',sheet_name, ...
        'Range',col_labels(stim_idx + 1*num_stimulations) + string(11 + Summary.stimulation_channel_number(stim_idx)));
    writecell({stimulation_channel_value},excelfile,'Sheet',sheet_name, ...
        'Range',col_labels(stim_idx + 2*num_stimulations) + string(11 + Summary.stimulation_channel_number(stim_idx)));
    writecell({stimulation_channel_value},excelfile,'Sheet',sheet_name, ...
        'Range',col_labels(stim_idx + 3*num_stimulations) + string(11 + Summary.stimulation_channel_number(stim_idx)));


    % "neighbor_channel_value" for the neighboring channels
    for k = 1:length(Summary.neighbor_channel_number{stim_idx})
        writecell({neighbor_channel_value},excelfile,'Sheet',sheet_name, ...
            'Range',col_labels(stim_idx + 0*num_stimulations) + string(11 + Summary.neighbor_channel_number{stim_idx}(k)));
        writecell({neighbor_channel_value},excelfile,'Sheet',sheet_name, ...
            'Range',col_labels(stim_idx + 1*num_stimulations) + string(11 + Summary.neighbor_channel_number{stim_idx}(k)));
        writecell({neighbor_channel_value},excelfile,'Sheet',sheet_name, ...
            'Range',col_labels(stim_idx + 2*num_stimulations) + string(11 + Summary.neighbor_channel_number{stim_idx}(k)));
        writecell({neighbor_channel_value},excelfile,'Sheet',sheet_name, ...
            'Range',col_labels(stim_idx + 3*num_stimulations) + string(11 + Summary.neighbor_channel_number{stim_idx}(k)));
    end
end

% Insert "bad_channel_value" for the predefined bad channels
bad_idx = find(exclude_bad_channel_mask);
for j = 1:length(bad_idx)
    writecell({repelem(bad_channel_value,4*num_stimulations)},excelfile,'Sheet',sheet_name, ...
        'Range',col_labels(1) + string(11 + bad_idx(j)));
end

% Ouptut to screen
[~,I] = fileparts(excelfile);
fprintf('Sheet "%s" in File "%s" is saved successfully ...\n', sheet_name, I + ".xlsx");

% Write the file/cycle information
col_labels = excel_column_labels(num_stimulations + 1);
sheet_name = string(erase(info{1,1},".edf")) + "_info";
sheet_name = extractBetween(sheet_name, 1, min(strlength(sheet_name), 31)); % limit induced by excel sheet naming
writecell({'File:';'Time start:';'Time end:';'Stimulation frequency (Hz):'; ...
    'Stimulation current (mA):';'Number of stimulation cycles'}, ...
    excelfile,'Sheet',sheet_name,'Range','A1');
writecell(info(1:6),excelfile,'Sheet',sheet_name,'Range','B1');
writecell({"Stimulus number"},excelfile,'Sheet',sheet_name,'Range','A8');
MAX_num_stimulus = 0;
for stim_idx = 1:num_stimulations  % iterate through the stimulation cycles
    MAX_num_stimulus = max(size(Summary.stimulation_pulses_location{stim_idx},1),MAX_num_stimulus);
    writecell({"Stimulus time (cycle " + stim_idx + ": " + Summary.stimulation_channel_label(stim_idx) ...
        + ")"},excelfile,'Sheet',sheet_name,'Range',col_labels(1+stim_idx) + '8');
    pulse_loc = seconds((Summary.stimulation_pulses_location{stim_idx} - sample_window)/fs) + start_datetime;
    pulse_loc.Format = "dd-MMMM-yyyy HH:mm:ss.SSSSSSSSS";
    writematrix(string(pulse_loc),excelfile,'Sheet',sheet_name,'Range',col_labels(1+stim_idx) + '9');
end
writematrix((1:MAX_num_stimulus)',excelfile,'Sheet',sheet_name,'Range','A9');
writecell({"Stimulus number"},excelfile,'Sheet',sheet_name,'Range','A8');
writecell({'Cycle duration (sec):';'Cycle duration with artefacts removed (sec):'}, ...
    excelfile,'Sheet',sheet_name,'Range','A' + string(9+MAX_num_stimulus));
writematrix(duration_original,excelfile,'Sheet',sheet_name,'Range','B' + string(9+MAX_num_stimulus));
writematrix(duration_artefacts_removed,excelfile,'Sheet',sheet_name,'Range','B' + string(10+MAX_num_stimulus));

% Ouptut to screen
[~,I] = fileparts(excelfile);
fprintf('Sheet "%s" in File "%s" is saved successfully ...\n', sheet_name, I + ".xlsx");
end