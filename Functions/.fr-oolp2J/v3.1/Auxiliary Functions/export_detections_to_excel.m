function export_detections_to_excel(excelfile, sheet_name, info, bipolar_channels, user_measure, appear_rate, occupancy_rate, exclude_channel_idx)

% Write the file information
writecell({'File:';'Time start:';'Time end:';'Original duration (min):'; ...
    'Duration with artefacts removed (min):';'Duration with seizures removed (min):'; ...
    'Duration with both removed (min):';'Notes:'},excelfile,'Sheet',sheet_name,'Range','A1');
writecell(info,excelfile,'Sheet',sheet_name,'Range','B1');

% Write the channel numbers and labels
writematrix((1:length(bipolar_channels))',excelfile,'Sheet',sheet_name,'Range','A11');
writematrix(bipolar_channels,excelfile,'Sheet',sheet_name,'Range','B11');

% Write column headers
user_measure = upper(user_measure);
main_hdr = repelem({""},1,8);
if strcmpi(user_measure,"s")
    main_hdr{1} = "IED rate (1/min)";
    main_hdr{5} = "IED occupancy (%)";
else
    main_hdr{1} = user_measure + " rate (1/min)";
    main_hdr{5} = user_measure + " occupancy (%)";
end
sub_hdr = cat(2,{'Channel number','Channel label'},repmat({'Original','Artefacts removed','Seizures removed','Both removed'},1,2));
writecell(main_hdr,excelfile,'Sheet',sheet_name,'Range','C9');
writecell(sub_hdr,excelfile,'Sheet',sheet_name,'Range','A10');

% Write the measure rates and percentages of occupancy
writematrix(appear_rate,excelfile,'Sheet',sheet_name,'Range',"C11");
writematrix(occupancy_rate,excelfile,'Sheet',sheet_name,'Range',"G11");

% Insert "bad_channel_value" for the predefined bad channels
bad_channel_value = strsplit(info{8,1});
bad_channel_value = bad_channel_value(1);
col_labels = excel_column_labels(10);
col_labels = col_labels(3:end);
for j = 1:length(exclude_channel_idx)
    writecell({repelem(bad_channel_value,8)},excelfile,'Sheet',sheet_name, ...
        'Range',col_labels(1) + string(11 + exclude_channel_idx(j) - 1));
end

% Ouptut to screen
[~,I] = fileparts(excelfile);
fprintf('Sheet "%s" in File "%s" is saved successfully ...\n', sheet_name, I + ".xlsx");
end