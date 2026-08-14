function user_datetime_range = check_datetime(user_datetime_range)
%% Unify input datetime format (updated on 19.5.2026 by Mohammad Al-Sa'd)
formats = [
    "dd-MM-yyyy HH:mm:ss"      % 15-01-2021 01:05:00
    "dd-MMM-yyyy HH:mm:ss"     % 15-Jan-2021 01:05:00
    "dd-MMMM-yyyy HH:mm:ss"    % 15-January-2021 01:05:00
    "dd-MM-yyyy HH.mm.ss"      % 15-01-2021 01.05.00
    "dd-MMM-yyyy HH.mm.ss"     % 15-Jan-2021 01.05.00
    "dd-MMMM-yyyy HH.mm.ss"    % 15-January-2021 01.05.00
    "dd/MM/yyyy HH:mm:ss"      % 15/01/2021 01:05:00
    "dd/MMM/yyyy HH:mm:ss"     % 15/Jan/2021 01:05:00
    "dd/MMMM/yyyy HH:mm:ss"    % 15/January/2021 01:05:00
    "dd/MM/yyyy HH.mm.ss"      % 15/01/2021 01.05.00
    "dd/MMM/yyyy HH.mm.ss"     % 15/Jan/2021 01.05.00
    "dd/MMMM/yyyy HH.mm.ss"    % 15/January/2021 01.05.00

    ]; % supported styles
x = string(user_datetime_range);
dt = NaT(size(x));
for i = 1:numel(formats)
    idx = isnat(dt);
    try
        tmp = datetime(x(idx), 'InputFormat', formats(i));
        dt(idx) = tmp;
    catch
    end
end
dt.Format = 'dd-MMM-yyyy HH:mm:ss';

%% Main checking
user_datetime_range{1} = datetime(dt(1));
user_datetime_range{2} = datetime(dt(2));
if user_datetime_range{1} >= user_datetime_range{2}
    error('The start datetime must be less than the end datetime!');
end
if isnat(user_datetime_range{1}) && ~isnat(user_datetime_range{2})
    fprintf('The selected datetime range is earliest datetime - %s\n',user_datetime_range{2});
elseif ~isnat(user_datetime_range{1}) && isnat(user_datetime_range{2})
    fprintf('The selected datetime range is %s - latest datetime\n', ...
        user_datetime_range{1});
elseif isnat(user_datetime_range{1}) && isnat(user_datetime_range{2})
    fprintf('The selected datetime range is earliest datetime - latest datetime\n');
else
    fprintf('The selected datetime range is %s - %s\n',user_datetime_range{1},user_datetime_range{2});
end
end