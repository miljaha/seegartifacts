function new_windows = split_windows(sample_window, max_length, min_length)
 
    new_windows = [];

    for i = 1:size(sample_window,2)
        start_i = sample_window(1,i);
        end_i   = sample_window(2,i);
        len_i   = end_i - start_i;

        if len_i < min_length
            new_windows = [new_windows, [start_i; end_i]];
            continue;
        end

        if len_i <= max_length
            % window is already OK
            new_windows = [new_windows, [start_i; end_i]];
            continue
        end

        current_start = start_i;

        while current_start + max_length < end_i
            % Add chunk
            new_windows = [new_windows, ...
                [current_start; current_start + max_length]];
            current_start = current_start + max_length;
        end

        % Handle the leftover part
        leftover = end_i - current_start;

        if leftover >= min_length
            % Large enough: keep
            new_windows = [new_windows, [current_start; end_i]];
        else
            % Too short: merge with previous window
            if ~isempty(new_windows)
                % Extend previous window up to end_i
                new_windows(:,end) = [new_windows(1,end); end_i];
            else
                % No previous window → keep as-is
                new_windows = [new_windows, [current_start; end_i]];
            end
        end
    end
end
