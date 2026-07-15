function reformatted = extract_bad_channels(badchans_raw)
    % normalize all delimiters to spaces first
    badchans_raw = badchans_raw{1};
    badchans_raw = regexprep(badchans_raw, '[;,]', ' ');

    tokens = regexp(badchans_raw, "[^\s')(?&]*-[^\s')(?&]*", 'match');
    expanded_channels = {};
    current_electrode = '';

    for i = 1:numel(tokens)
        tok = tokens{i};

        m = regexp(tok, '^(.*?)(\d+)-(\d+)$', 'tokens', 'once');
        if isempty(m)
            continue
        end

        elec = m{1};
        n1 = str2double(m{2});
        n2 = str2double(m{3});

        if ~isempty(elec)
            current_electrode = upper(elec);
        end

        for k = n1:(n2-1)
            expanded_channels{end+1} = sprintf('%s%02d-%02d', current_electrode, k, k+1);
        end
    end
    reformatted = cell(size(expanded_channels));
    for i = 1:numel(expanded_channels)
        ch = lower(expanded_channels{i});
        m = regexp(ch, '^(.*?)(\d+)-(\d+)$', 'tokens', 'once');
        reformatted{i} = sprintf('%s%s-%s%s', m{1}, m{2}, m{1}, m{3});
    end
end