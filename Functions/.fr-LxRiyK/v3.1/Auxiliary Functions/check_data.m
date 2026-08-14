function [fs, N, label, events] = check_data(data_dir, file_name)
%%% Updated on 20.5.2026 by Mohammad Al-Sa'd

%% Checking the edf file and extracting information
EDFhdr = MemReadEDF(fullfile(data_dir, file_name),'annotations'); % load annotations and edf header
[~, annotation_temp] = MemReadEDF(fullfile(data_dir, file_name),'time',[0 EDFhdr.Duration]); % load a single record for checking
fs = EDFhdr.SamplingRate(1); % get the edf file sampling rate
M = size(annotation_temp,2); % number of seeg channels
N = EDFhdr.NumRecords*EDFhdr.NumSamples(1); % total number of samples
label = string(erase(EDFhdr.ChanLabel(1:M)',"POL ")); % remove "POL " from the channel labels
label = upper(erase(lower(label),{'eeg','ref','-',' ','_'})); % remove additional trailings
fprintf('File "%s" is OK \n', file_name);

%% Searching and loading annotations
annotation_file = find_annotation_file(file_name, data_dir); % seraching for external annotation file
Iedf = isfield(EDFhdr,"Annotations");  % do annotations exist in the edf file
Iext = ~isempty(annotation_file);      % do annotations exist in an external file

if Iext % priority 1, external file
    fprintf("Loading annotations from external file ""%s""\n",annotation_file);
    [~, ~, exts] = fileparts(annotation_file); % get external file extension
    switch exts
        case {".xlsx", ".xls", ".csv"}
            temp = readtable(fullfile(data_dir,annotation_file),'VariableNamingRule','preserve');
            annotation_temp = [string(temp.Begin) string(temp.End), ...
                string(temp.Duration) string(temp.Definition) string(temp.Text)];
        case {".txt"}
            lines = readlines(fullfile(data_dir,annotation_file));
            lines = strip(lines); % remove empty start or end characters
            lines(lines == "") = []; % remove empty lines
            lines = lines(2:end); % skip header
            annotation_temp = strings(size(lines,1), 5);   % Start, End, Duration, Definition, Comment
            for i = 1:size(lines,1)
                tmp = regexp(lines(i), '\s{2,}', 'split');
                tmp = strip(tmp);
                n = min(numel(tmp), 5); % in case we have more fields for whatever reason
                annotation_temp(i,:) = tmp(1:n);
            end
    end

    event_datetime = duration(annotation_temp(:,1), "InputFormat", "hh:mm:ss.SSS");
    start_day_offset = [0; cumsum(diff(event_datetime) < 0)];
    rec_date = datetime(EDFhdr.StartDate,"InputFormat","dd.MM.yy");
    rec_time = datetime([EDFhdr.StartDate ' ' EDFhdr.StartTime],"InputFormat","dd.MM.yy HH.mm.ss");
    event_datetime = datetime(rec_date + days(start_day_offset) + event_datetime,"format","dd-MMMM-yyyy HH:mm:ss.SSS");
    event_sample = round(seconds(event_datetime - rec_time)*fs) + 1;
    events = struct( ...
        "value",     cellstr(string(annotation_temp(:,5))).', ...
        "sample",    num2cell(event_sample(:).'), ...
        "timestamp", num2cell((event_sample(:).'-1) / fs), ...
        "duration",  num2cell(zeros(1, size(annotation_temp,1))));

elseif Iedf % priority 2, internal edf
    fprintf("Loading annotations from internal file ""%s""\n",file_name);
    events = EDFhdr.Annotations;   % get the annotations from the edf file
    if any(isnan([events.sample])) % check for invalid markers
        warning("Some annotation markers are invalid!");
        events(isnan([events.sample])) = []; % remove invalid annotations
        disp('Removing invalid annotations is complete');
    end

else
    error('File ""%s"" has no internal or external annotations \n', file_name);
end

%% Check if events exist in annotations
if isempty([events.sample])
    fprintf("The file has NO annotated events\n");    
else
    fprintf("The file has %d annotated events\n", length(events));
end

end