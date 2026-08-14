function [data_dir, edf_filename] = check_dir(data_dir, data_files)
if exist(data_dir,"file") > 0  % check if the data directory exists
    F = dir(fullfile(data_dir, "*.edf"));    % list all edf files in the subject's directory
    edf_filename = string({F.name}');        % gather all edf filenames
    if isempty(edf_filename) % check if there are any edf files in the directory
        error('There are no EDF files in the selected directory!');
    else
        data_files = string(data_files);
        if ~(length(data_files) == 1 && strcmp(data_files(1),"")) % check if data file selection is auto or manual
            fprintf('Data file selection mode is manual\n');
            temp = intersect(data_files,edf_filename); % get subset of the edf filenames
            if isempty(temp) % check if the selected files exist
                error('The selected EDF files do not exist in the selected directory!');
            else
                file_cond = ismember(data_files,temp); % check which files dont exist
                for i = 1:length(data_files)
                    fprintf('The data file "%s"', data_files(i));
                    if file_cond(i)
                        fprintf(" is OK\n");
                    else
                        fprintf(2," does not exist!\n");
                    end
                end
                edf_filename = temp;
            end
        else
            fprintf('Data file selection mode is automatic\n');
        end
    end
else
    error('Data directory does not exist!');
end
end