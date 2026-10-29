function labelSignals(src, savefile, fs, showMeta, randomize)
% src: path to a .mat file containing the struct gui_data, or the struct itself
%   gui_data.signal_samples : 2 x T x n  (1 = raw, 2 = HFB)
%   gui_data.info           : n x 5 cell [score, channel, name, bad, patient]
%                             columns 6 (label) and 7 (time) are added if missing
% savefile: required if src is a struct; ignored if src is a path
if nargin < 3, fs = 2048; end
if nargin < 4, showMeta = true; end
if nargin < 5, randomize = true; end

if ischar(src) || isstring(src)
    savefile = char(src);
    S = load(savefile);
    gui_data = S.gui_data;
else
    assert(nargin >= 2, 'Give a savefile when passing gui_data as a struct.');
    gui_data = src;
end
signal_samples = gui_data.samples;
info = gui_data.info;

% column positions in info
cScore = 1; cChan = 2; cName = 3; cBad = 4; cPat = 5; cLabel = 6; cTime = 7;

catNames = {'Artifact','Non-artifact'};
n = size(signal_samples,3);
assert(size(info,1) == n, 'info has %d rows but signal_samples has %d epochs.', size(info,1), n);
t = (0:size(signal_samples,2)-1)/fs;

% add label columns the first time
if size(info,2) < cLabel, info(:,cLabel) = num2cell(zeros(n,1)); end   % 0 = unlabeled
if size(info,2) < cTime,  info(:,cTime)  = repmat({NaT},n,1); end

% deterministic presentation order (does not touch the global rng)
if randomize
    order = randperm(RandStream('twister','Seed',1), n);
else
    order = 1:n;
end
pos = find(getLabels(order)==0,1); if isempty(pos), pos = 1; end

fig = uifigure('Name','Signal labeling','Position',[100 100 1100 600]);
g = uigridlayout(fig,[1 2]); g.ColumnWidth = {'1x',230};

pl = uigridlayout(g,[2 1]);
ax1 = uiaxes(pl); title(ax1,'Raw signal');                 ylabel(ax1,'Amplitude');
ax2 = uiaxes(pl); title(ax2,'250-500 Hz filtered signal'); ylabel(ax2,'Amplitude');
xlabel(ax2,'Time (s)');
h1 = plot(ax1,t,nan(size(t))); h2 = plot(ax2,t,nan(size(t)));
linkaxes([ax1 ax2],'x'); xlim(ax1,[t(1) t(end)]);

cp = uigridlayout(g,[8 1]);
cp.RowHeight = [{'1x'}, repmat({40},1,7)];
lbl = uilabel(cp,'FontSize',14,'VerticalAlignment','top','WordWrap','on');
uibutton(cp,'Text',[catNames{1} '  (1)'],'ButtonPushedFcn',@(~,~) setLabel(1));
uibutton(cp,'Text',[catNames{2} '  (2)'],'ButtonPushedFcn',@(~,~) setLabel(2));
uibutton(cp,'Text','Clear label','ButtonPushedFcn',@(~,~) setLabel(0));
uibutton(cp,'Text','< Prev','ButtonPushedFcn',@(~,~) step(-1));
uibutton(cp,'Text','Next >','ButtonPushedFcn',@(~,~) step(1));
uibutton(cp,'Text','Next unlabeled','ButtonPushedFcn',@(~,~) nextUnlabeled());
uibutton(cp,'Text','Export CSV','ButtonPushedFcn',@(~,~) exportCsv());

fig.KeyPressFcn = @keyHandler;
render();

fig.KeyPressFcn = @keyHandler;
render();
uiwait(fig);        % block until the window is closed

    function v = getLabels(rows)
        if nargin < 1, rows = 1:n; end
        v = cellfun(@double, info(rows,cLabel));
    end

    function s = toStr(x)
        s = string(x);
        s = s(1);
    end

    function render()
        idx = order(pos);
        h1.YData = signal_samples(1,:,idx);
        h2.YData = signal_samples(2,:,idx);
        cur = info{idx,cLabel};
        states = [{'UNLABELED'}, catNames];
        txt = sprintf('Epoch %d / %d\nLabel: %s\n\nPatient: %s\nChannel: %s\nName: %s', ...
            pos, n, states{cur+1}, toStr(info{idx,cPat}), ...
            toStr(info{idx,cChan}), toStr(info{idx,cName}));
        if showMeta
            bad = {'no','yes'};
            txt = sprintf('%s\nCNN score: %.3f\nBad channel: %s', ...
                txt, info{idx,cScore}, bad{info{idx,cBad}+1});
        end
        txt = sprintf('%s\n\nDone: %d / %d', txt, nnz(getLabels()), n);
        lbl.Text = txt;
        if cur==0, lbl.FontColor = [0.8 0.1 0.1]; else, lbl.FontColor = [0.1 0.5 0.1]; end
    end

    function setLabel(v)
        idx = order(pos);
        info{idx,cLabel} = v;
        if v==0, info{idx,cTime} = NaT; else, info{idx,cTime} = datetime('now'); end
        gui_data.info = info;
        save(savefile,'gui_data');
        if v ~= 0 && pos < n, pos = pos+1; end
        render();
    end

    function goTo(k), pos = min(max(k,1),n); render(); end
    function step(d), goTo(pos + d); end

    function nextUnlabeled()
        k = find(getLabels(order)==0,1);
        if ~isempty(k), pos = k; render(); end
    end

    function exportCsv()
        patient = arrayfun(@(i) toStr(info{i,cPat}),  (1:n)');
        chan    = arrayfun(@(i) toStr(info{i,cChan}), (1:n)');
        name    = arrayfun(@(i) toStr(info{i,cName}), (1:n)');
        score   = cellfun(@double, info(:,cScore));
        bad     = cellfun(@double, info(:,cBad));
        time    = vertcat(info{:,cTime});
        T = table((1:n)', patient, chan, name, score, bad, getLabels(), time, ...
            'VariableNames',{'epoch','patient','channel','name','cnn_score','bad_channel','label','time'});
        writetable(T, strrep(savefile,'.mat','.csv'));
    end

    function keyHandler(~,e)
        switch e.Key
            case {'1','numpad1'}, setLabel(1);
            case {'2','numpad2'}, setLabel(2);
            case 'rightarrow',    step(1);
            case 'leftarrow',     step(-1);
        end
    end
end