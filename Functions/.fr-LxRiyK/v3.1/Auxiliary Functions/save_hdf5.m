function save_hdf5(filename, varargin)
% SAVE_HDF5  Save named variables to HDF5 using their MATLAB names

    if exist(filename,'file')
        delete(filename); % avoid stale/partial structures while debugging
    end
    fid = H5F.create(filename);
    H5F.close(fid);

    for k = 1:numel(varargin)
        varname = inputname(k+1);
        if isempty(varname)
            error('All inputs must be named variables.');
        end
        save_any_hdf5(filename, ['/' varname], varargin{k});
    end
end

function save_any_hdf5(filename, path, data)

    if istable(data)
        S = table2struct(data, 'ToScalar', true);
        S.varNames = data.Properties.VariableNames;
        if ~isempty(data.Properties.RowNames)
            S.rowNames = data.Properties.RowNames;
        end
        save_any_hdf5(filename, path, S);
        return
    end

    if isnumeric(data)
        dt = class(data);
        if ~h5exists(filename, path)
            h5mkdir(filename, fileparts(path));
            if isempty(data), data = NaN; end
            h5create(filename, path, size(data), 'Datatype', dt);
        end
        h5write(filename, path, data);

    elseif islogical(data)
        x = uint8(data);
        if ~h5exists(filename, path)
            h5mkdir(filename, fileparts(path));
            h5create(filename, path, size(x), 'Datatype', 'uint8');
        end
        h5write(filename, path, x);

    elseif isstring(data)
        if ~h5exists(filename, path)
            h5mkdir(filename, fileparts(path));
            if isempty(data), data = "NaN"; end
            h5create(filename, path, size(data), 'Datatype', 'string');
        end
        h5write(filename, path, data);

    elseif ischar(data)
        s = string(data);
        if ~h5exists(filename, path)
            h5mkdir(filename, fileparts(path));
            if isempty(data), s = "NaN"; end
            h5create(filename, path, size(s), 'Datatype', 'string');
        end
        h5write(filename, path, s);

    elseif isstruct(data)
        h5mkdir(filename, path); % ensure the group exists
        f = fieldnames(data);
        for i = 1:numel(f)
            save_any_hdf5(filename, [path '/' f{i}], data.(f{i}));
        end

    elseif iscell(data)
        h5mkdir(filename, path); % store cells under a group
        for i = 1:numel(data)
            save_any_hdf5(filename, sprintf('%s/%d', path, i), data{i});
        end

    else
        error("Unsupported type: %s", class(data));
    end
end

function h5mkdir(filename, gpath)
% Create HDF5 groups along gpath (mkdir -p)
    if isempty(gpath) || strcmp(gpath,'.') || strcmp(gpath,'/'), return; end
    parts = split(strip(gpath,'/'), '/');
    cur = '';
    for i = 1:numel(parts)
        cur = ['/' strjoin(parts(1:i), '/')];
        if ~h5exists(filename, cur)
            fid = H5F.open(filename, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
            gid = H5G.create(fid, cur, 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
            H5G.close(gid);
            H5F.close(fid);
        end
    end
end

function tf = h5exists(filename, path)
    try
        h5info(filename, path);
        tf = true;
    catch
        tf = false;
    end
end
