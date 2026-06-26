function expanded_channels = extract_bad_channels(badchans_raw)

    tokens = regexp(badchans_raw, "[^\s,')(?&]*-[^\s,')(?&]*", 'match');
    tokens = tokens{1};
    expanded_channels = {};
    current_electrode = '';
    
    for i = 1:numel(tokens)
        tok = tokens{i};
        
        % capture optional letters + first number + second number
        m = regexp(tok, '^(.*?)(\d+)-(\d+)$', 'tokens', 'once');
        if isempty(m)
            continue  % skip anything that doesn't match the expected shape
        end
        
        elec = m{1};
        n1 = str2double(m{2});
        n2 = str2double(m{3});
        
        % if this token has a letter prefix, update "current" electrode name
        if ~isempty(elec)
            current_electrode = upper(elec);
        end
        
        % expand into consecutive bipolar pairs (handles both normal AND shorthand cases)
        for k = n1:(n2-1)
            expanded_channels{end+1} = sprintf('%s%02d-%02d', current_electrode, k, k+1);
        end
    end
end