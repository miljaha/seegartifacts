function col_labels = excel_column_labels(N)
    col_labels = strings(1, N); % Preallocate as string array
    for k = 1:N
        label = "";
        n = k;
        while n > 0
            n = n - 1;
            label = char(mod(n,26) + 'A') + label;
            n = floor(n / 26);
        end
        col_labels(k) = label;
    end
end