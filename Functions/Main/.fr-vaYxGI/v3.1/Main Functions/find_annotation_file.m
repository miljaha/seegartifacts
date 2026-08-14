function annotation_filename = find_annotation_file(edf_filename, data_dir)
%% List all candidate annotation files
annot_exts = [".txt", ".csv", ".xlsx", ".xls"]; % Supported annotation file types
files = [];
for i = 1:numel(annot_exts)
    files = cat(1,files,dir(fullfile(data_dir, "*" + annot_exts(i))));
end
if isempty(files)
    annotation_filename = [];
    return
end
candidate_annotation_filenames = string({files.name}).';

%% Progressive matching annotation files with the edf filename
[~, edf_base, ~] = fileparts(edf_filename);
search_key = string(edf_base);
while strlength(search_key) > 0

    % match files that start with the current search key
    is_match = startsWith(candidate_annotation_filenames, search_key, "IgnoreCase", true);

    if any(is_match)
        matched_files = candidate_annotation_filenames(is_match);

        % choose preferred file if multiple matches exist
        annotation_filename = select_preferred_file(matched_files);
        return
    end

    % remove the last part after '_' or '-'
    new_key = regexprep(search_key, '[_-][^_-]+$', '');

    % stop if nothing changed
    if new_key == search_key
        break
    end
    search_key = new_key;
end

%% No match found
annotation_filename = [];

end
%% Auxillary function to select one prefered annotation format
function annot_file = select_preferred_file(matched_files)
preferred_order = [".xlsx", ".xls", ".csv", ".txt"]; % Preferred annotation type order
[~, ~, exts] = fileparts(matched_files);
exts = lower(exts);
for i = 1:numel(preferred_order)
    idx = find(exts == preferred_order(i), 1, "first");

    if ~isempty(idx)
        annot_file = matched_files(idx);
        return
    end
end
end