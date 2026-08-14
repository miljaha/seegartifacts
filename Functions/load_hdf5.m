
function S = load_hdf5(filename, path)
% LOAD_HDF5  Recursively load HDF5 subtree into a nested struct.
    if nargin < 2, path = '/'; end
    S = read_group(filename, path);
end

function out = read_group(filename, path)
    info = h5info(filename, path);
    out = struct();

    % datasets in this group
    for i = 1:numel(info.Datasets)
        name  = info.Datasets(i).Name;
        dpath = fullpath(path, name);
        out.(matlab.lang.makeValidName(name)) = h5read(filename, dpath);
    end

    % subgroups
    for i = 1:numel(info.Groups)
        gpath = info.Groups(i).Name;
        [~, gname] = fileparts(gpath);
        out.(matlab.lang.makeValidName(gname)) = read_group(filename, gpath);
    end
end

function p = fullpath(base, name)
    if strcmp(base,'/'), p = ['/' name];
    else,               p = [base '/' name];
    end
end
