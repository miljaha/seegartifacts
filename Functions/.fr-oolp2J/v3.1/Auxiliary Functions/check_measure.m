function user_measure = check_measure(user_measure, short_list_of_measures, complete_list_of_measures)
if isempty(user_measure) || ~any(ismember(lower(user_measure), short_list_of_measures)) % check if the selected measure is supported
    user_measure = "fr";
    fprintf('The default Fast-Ripples option is selected\n');
else
    user_measure = lower(user_measure);
    user_measure(user_measure == "") = []; % remove empty entires
    I_measure = find(ismember(short_list_of_measures, user_measure)); % check which measures are selected
    user_measure = short_list_of_measures(I_measure); % only keep valid measures
    if length(I_measure) > 1 % if more than one measure is selected
        fprintf('The selected detection measures are:\n');
        for i = 1:length(I_measure)
            fprintf('(%d) %s\n', i, complete_list_of_measures(I_measure(i)));
        end
    else % if only one measure is selected
        fprintf('The selected detection measure is %s\n', complete_list_of_measures(I_measure));
    end
end
end