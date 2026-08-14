function [requested_current, requested_frequency] = check_stim_parameters(requested_current, requested_frequency)
requested_current   = double(string(regexp(string(requested_current), '[+-]?\d+\.?\d*', 'match')));         % Extract the requested stimulation current
requested_frequency = double(string(regexp(string(requested_frequency), '[+-]?\d+\.?\d*', 'match')));       % Extract the requested stimulation frequency
if isempty(requested_current)
    requested_current = 5;
    fprintf('The default 5 mA current is selected\n');
else
    fprintf('The selected current is %s mA\n', string(requested_current));
end
if isempty(requested_frequency)
    fprintf('The default 1 Hz frequency is selected\n');
    requested_frequency = 1;
else
    fprintf('The selected frequency is %s Hz\n', string(requested_frequency));
end
end