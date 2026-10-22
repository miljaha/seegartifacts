function labelSignals(signal_samples, info, chanNames, fs, savefile, showMeta, randomize)
% signal_samples: 2 x T x n   (1 = raw, 2 = HFB)
% info columns:   [CNN score, channel number, (unused), bad channel flag]
% chanNames:      n x 1 cell array of channel names
if nargin < 4, fs = 2048; end
if nargin < 5, savefile = 'labels.mat'; end
if nargin < 6, showMeta = true; end     % false = hide CNN score / bad flag
if nargin < 7, randomize = true; end    % shuffle presentation order

catNames = {'Artifact','Non-artifact'};   % rename to your real categories
n = size(signal_samples,3);
t = (0:size(signal_samples,2)-1)/fs;

if isfile(savefile)
    S = load(savefile);
    labels = S.labels; labelTime = S.labelTime; order = S.order;
else
    labels = zeros(n,1);               % 0 = unlabeled
    labelTime = NaT(n,1);
    if randomize, rng(1); order = randperm(n); else, order = 1:n; end
end
pos = find(labels(order)==0,1); if isempty(pos), pos = 1; end

fig = uifigure('Name','Signal labeling','Position',[100 100 1100 600]);
g = uigridlayout(fig,[1 2]); g.ColumnWidth = {'1x',230};

pl = uigridlayout(g,[2 1]);
ax1 = uiaxes(pl); title(ax1,'Raw signal');          ylabel(ax1,'Amplitude');
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

    function render()
        idx = order(pos);
        h1.YData = signal_samples(1,:,idx);
        h2.YData = signal_samples(2,:,idx);
        states = [{'UNLABELED'}, catNames];
        txt = sprintf('Epoch %d / %d\nLabel: %s\n\nChannel: %d\nName: %s', ...
            pos, n, states{labels(idx)+1}, info(idx,2), chanNames{idx});
        if showMeta
            bad = {'no','yes'};
            txt = sprintf('%s\nCNN score: %.3f\nBad channel: %s', ...
                txt, info(idx,1), bad{info(idx,4)+1});
        end
        txt = sprintf('%s\n\nDone: %d / %d', txt, nnz(labels), n);
        lbl.Text = txt;
        if labels(idx)==0, lbl.FontColor = [0.8 0.1 0.1]; else, lbl.FontColor = [0.1 0.5 0.1]; end
    end

    function setLabel(v)
        idx = order(pos);
        labels(idx) = v;
        if v==0, labelTime(idx) = NaT; else, labelTime(idx) = datetime('now'); end
        save(savefile,'labels','labelTime','order','info','chanNames');
        if v ~= 0 && pos < n, pos = pos+1; end
        render();
    end

    function goTo(k), pos = min(max(k,1),n); render(); end
    function step(d), goTo(pos + d); end
    function nextUnlabeled()
        k = find(labels(order)==0,1);
        if ~isempty(k), pos = k; render(); end
    end

    function exportCsv()
        T = table((1:n)', info(:,2), chanNames, info(:,1), info(:,4), labels, labelTime, ...
            'VariableNames',{'epoch','channel','name','cnn_score','bad_channel','label','time'});
        writetable(T, strrep(savefile,'.mat','.csv'));
    end

    function keyHandler(~,e)
        switch e.Key
            case {'1','numpad1'}, setLabel(1);
            case {'2','numpad2'}, setLabel(2);
            case 'rightarrow',    goTo(pos+1);
            case 'leftarrow',     goTo(pos-1);
        end
    end
end