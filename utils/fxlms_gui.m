function fig = fxlms_gui(parent)
% FXLMS_GUI  使用与 `signal_generator_gui` 类似的界面布局
% - 顶部选择条，左侧参数面板，右侧操作面板，中央/下方绘图区，底部按钮与状态栏
% If `parent` is provided (uitab/uipanel), the UI is built inside that
% container. If not provided, a new figure is created and used as parent.

% respect optional parent container
if nargin<1 || isempty(parent)
    close all;
    fig = figure('Name','FXLMS GUI','NumberTitle','off','MenuBar','none','ToolBar','none', 'Units','normalized','Position',[0.15 0.10 0.70 0.75]);
    parent = fig;
    set(fig, 'DefaultUicontrolFontSize', 10, 'DefaultUipanelFontSize', 10);
else
    % embed into provided container (tab/panel). guidata must still use the
    % parent figure for storage, so find it.
    fig = ancestor(parent,'figure');
    if isempty(fig) || ~ishandle(fig)
        error('Parent must be a valid UI container inside a figure');
    end
end

% ---------------- Top: selectors ----------------
 uicontrol('Parent',parent,'Style','text','Units','normalized','Position',[0.02 0.92 0.10 0.05], 'String','Noise:','HorizontalAlignment','left');
 % Allow selecting generated signal type (Sine/Square/Band-limited) or From file
 hNoise = uicontrol('Parent',parent,'Style','popupmenu','Units','normalized','Position',[0.06 0.92 0.18 0.05], 'String',{'Sine','Square','Band-limited','From file'}, 'FontSize',10,'Callback',@onSignalTypeChanged);

uicontrol('Parent',parent,'Style','text','Units','normalized','Position',[0.25 0.92 0.08 0.05], 'String','Noise file:','HorizontalAlignment','left');
% Path display (read-only) and Browse button (wider, taller for readability)
hNoiseFile = uicontrol('Parent',parent,'Style','text','Units','normalized','Position',[0.30 0.95 0.20 0.02], 'String','data/whitenoise200-2kHz.bin','HorizontalAlignment','left','BackgroundColor',[1 1 1]);
hBrowse = uicontrol('Parent',parent,'Style','pushbutton','Units','normalized','Position',[0.45 0.95 0.05 0.02],'String','Browse...','Callback',@onBrowse);

% SysID file selectors (primary and secondary). Each is an edit + Browse.
uicontrol('Parent',parent,'Style','text','Units','normalized','Position',[0.02 0.90 0.12 0.04], 'String','SysID primary:','HorizontalAlignment','left');
hSysidPrimaryFile = uicontrol('Parent',parent,'Style','edit','Units','normalized','Position',[0.07 0.92 0.20 0.02], 'String','', 'HorizontalAlignment','left','BackgroundColor',[1 1 1]);
hSysidPrimaryBrowse = uicontrol('Parent',parent,'Style','pushbutton','Units','normalized','Position',[0.28 0.92 0.05 0.02],'String','Browse','Callback',@onSysidPrimaryBrowse,'TooltipString','Select primary LMS_SYSID*prim*.mat file');

uicontrol('Parent',parent,'Style','text','Units','normalized','Position',[0.36 0.90 0.12 0.04], 'String','SysID secondary:','HorizontalAlignment','left');
hSysidSecondaryFile = uicontrol('Parent',parent,'Style','edit','Units','normalized','Position',[0.42 0.92 0.20 0.02], 'String','', 'HorizontalAlignment','left','BackgroundColor',[1 1 1]);
hSysidSecondaryBrowse = uicontrol('Parent',parent,'Style','pushbutton','Units','normalized','Position',[0.63 0.92 0.05 0.02],'String','Browse','Callback',@onSysidSecondaryBrowse,'TooltipString','Select secondary LMS_SYSID*.mat file');
 % ---------------- Left: parameter panel (stacked with Actions in same column) ----------------

% Parameters panel (left) - contains algorithm params and a nested Signal subpanel
paramPanel = uipanel('Parent',parent,'Title','Parameters','Units','normalized','Position',[0.02 0.4 0.22 0.5]);

% --- Signal subpanel inside Parameters to hold signal-type specific controls ---
signalPanel = uipanel('Parent',paramPanel,'Title','Signal','Units','normalized','Position',[0.03 0.66 0.94 0.30]);
% Dynamic controls inside this panel are created by onSignalTypeChanged (driven by the top selector)

% reduce vertical spacing (tighter layout)

% Layout adjusted to avoid overlap with the Signal subpanel above.
% Positions use distinct Y values (top->bottom): Lw, Mu, UseEst, Duration, Fs, Save
uicontrol('Parent',paramPanel,'Style','text','Units','normalized','Position',[0.03 0.54 0.45 0.08],'String','Filter length (Lw):','HorizontalAlignment','left');
hLw = uicontrol('Parent',paramPanel,'Style','edit','Units','normalized','Position',[0.52 0.54 0.40 0.08],'String','512');

uicontrol('Parent',paramPanel,'Style','text','Units','normalized','Position',[0.03 0.44 0.45 0.08],'String','Step size μ:','HorizontalAlignment','left');
hMu = uicontrol('Parent',paramPanel,'Style','edit','Units','normalized','Position',[0.52 0.44 0.40 0.08],'String','5e-4');

uicontrol('Parent',paramPanel,'Style','text','Units','normalized','Position',[0.03 0.34 0.45 0.08],'String','Duration (s):','HorizontalAlignment','left');
hDuration = uicontrol('Parent',paramPanel,'Style','edit','Units','normalized','Position',[0.52 0.34 0.40 0.08],'String','8');

uicontrol('Parent',paramPanel,'Style','text','Units','normalized','Position',[0.03 0.24 0.45 0.08],'String','Sample rate (Hz):','HorizontalAlignment','left');
hFs = uicontrol('Parent',paramPanel,'Style','edit','Units','normalized','Position',[0.52 0.24 0.40 0.08],'String','48000');

uicontrol('Parent',paramPanel,'Style','text','Units','normalized','Position',[0.03 0.14 0.45 0.08],'String','Save results (MAT):','HorizontalAlignment','left');
hSave = uicontrol('Parent',paramPanel,'Style','checkbox','Units','normalized','Position',[0.52 0.14 0.40 0.08],'Value',0);

% ---------------- Actions panel (stacked under Parameters in same left column) ----------------
actionPanel = uipanel('Parent',parent,'Title','Actions','Units','normalized','Position',[0.02 0.1 0.22 0.30]);
 % larger Run button, Stop button removed, compact tips and visible status
uicontrol('Parent',actionPanel,'Style','pushbutton','Units','normalized','Position',[0.05 0.78 0.40 0.16],'String','Run', 'FontWeight','bold','FontSize',11,'Callback',@onRun);
% Progress bar drawn using a small axes inside the actionPanel. This
% ensures the text can be rendered transparently on top of the green fill.
hProgAx = axes('Parent',actionPanel,'Units','normalized','Position',[0.05 0.62 0.90 0.12],'XLim',[0 1],'YLim',[0 1],'Box','off','XTick',[],'YTick',[],'Visible','off');
hold(hProgAx,'on');
% background rectangle and initial fill rectangle (width 0)
hProgBgRect = rectangle('Parent',hProgAx,'Position',[0 0 1 1],'FaceColor',[0.92 0.92 0.92],'EdgeColor','none');
hProgFillRect = rectangle('Parent',hProgAx,'Position',[0 0 0 1],'FaceColor',[0.2 0.8 0.2],'EdgeColor','none');
% overlay text (transparent background within axes)
hProgText = text(0.5,0.5,'Ready','Parent',hProgAx,'Color',[0 0 0],'HorizontalAlignment','center','VerticalAlignment','middle','FontWeight','bold');
% make sure axes doesn't capture mouse events and is visually inert
set(hProgAx,'HitTest','off');
set(hProgBgRect,'HitTest','off'); set(hProgFillRect,'HitTest','off'); set(hProgText,'HitTest','off');
% Status box (placed under tips inside same column)
hStatus = uicontrol('Parent',actionPanel,'Style','text','Units','normalized','Position',[0.05 0.40 0.90 0.16],'String','Status: Ready','HorizontalAlignment','left');

% ---------------- Main plotting area (2x2 grid) ----------------
axTL = axes('Parent',parent,'Units','normalized','Position',[0.28 0.50 0.34 0.36]);
title(axTL,'Generated reference (preview)'); xlabel(axTL,'Time (s)'); ylabel(axTL,'Amplitude');

axTR = axes('Parent',parent,'Units','normalized','Position',[0.66 0.50 0.32 0.36]);
title(axTR,'Primary / Controlled / Error'); xlabel(axTR,'Time (s)'); ylabel(axTR,'Amplitude');

axBL = axes('Parent',parent,'Units','normalized','Position',[0.28 0.13 0.34 0.28]);
title(axBL,'Envelope Level (dB)');
xlabel(axBL,'Time (s)'); 
ylabel(axBL,'Level (dB)');

axBR = axes('Parent',parent,'Units','normalized','Position',[0.66 0.13 0.32 0.28]);
title(axBR,'Final weights (w)'); 
xlabel(axBR,'Tap index'); 
ylabel(axBR,'Amplitude');

% Bottom action strip (import/export/quantize) to mimic style
uicontrol('Parent',parent,'Style','pushbutton','Units','normalized','Position',[0.02 0.03 0.08 0.04],'String','Generate','Callback',@onGenerate);
uicontrol('Parent',parent,'Style','pushbutton','Units','normalized','Position',[0.15 0.03 0.08 0.04],'String','Export','Callback',@onExport);
uicontrol('Parent',parent,'Style','pushbutton','Units','normalized','Position',[0.28 0.03 0.08 0.04],'String','Export to Workspace','Tag','btn_export_ws','TooltipString','Export data to base workspace','Callback',@onExportToWorkspace);

% store handles in guidata if needed
% initialize unified importedData structure (canonical source for generated/imported signals)
initialImported = struct();
initialImported.floatY = [];
initialImported.t = [];
initialImported.fs = [];
initialImported.intVals = [];
initialImported.fileName = '';
initialImported.Nbits = 24;
initialImported.frac = 0;
initialImported.encodeType = '';
initialImported.meta = [];
initialImported.sourceType = 'none'; % 'none'|'generated'|'imported_file'|'imported_workspace'
initialImported.encodeParams = [];

handles = struct('hNoise',hNoise,'hNoiseFile',hNoiseFile,'hBrowse',hBrowse,'hSysidPrimaryFile',hSysidPrimaryFile,'hSysidPrimaryBrowse',hSysidPrimaryBrowse,'hSysidSecondaryFile',hSysidSecondaryFile,'hSysidSecondaryBrowse',hSysidSecondaryBrowse,'hDuration',hDuration,'hLw',hLw,'hMu',hMu,'hFs',hFs,'hSave',hSave,'hStatus',hStatus,'signalPanel',signalPanel,'hProgAx',hProgAx,'hProgFill',hProgFillRect,'hProgText',hProgText,'axTL',axTL,'axTR',axTR,'axBL',axBL,'axBR',axBR,'importedData',initialImported);
guidata(fig,handles);

% initialize signal parameter controls based on default selection
onSignalTypeChanged();

% ---------------- Nested callbacks ----------------
function onRun(~,~)
    handles = guidata(fig);
    set(handles.hStatus,'String','Status: Running'); drawnow;
    noiseList = get(handles.hNoise,'String'); noiseType = lower(noiseList{get(handles.hNoise,'Value')});
    params.noiseType = noiseType;
    params.noiseFile = get(handles.hNoiseFile,'String');
    params.fs = str2double(get(handles.hFs,'String'));
    params.duration = str2double(get(handles.hDuration,'String'));
    params.Lw = str2double(get(handles.hLw,'String'));
    params.mu = str2double(get(handles.hMu,'String'));
    params.saveResults = get(handles.hSave,'Value');
    % optional: user-provided SysID file paths for primary/secondary LMS_SYSID .mat
    try
        params.sysidPrimaryFile = get(handles.hSysidPrimaryFile,'String');
    catch
        params.sysidPrimaryFile = '';
    end
    try
        params.sysidSecondaryFile = get(handles.hSysidSecondaryFile,'String');
    catch
        params.sysidSecondaryFile = '';
    end
    % keep an optional folder fallback (for backward compatibility)
    try
        params.sysidDir = ''; % no-op by default; GUI no longer exposes folder control
    catch
        params.sysidDir = '';
    end
    % Prefer canonical imported/generated data stored in handles.importedData
    if isfield(handles,'importedData') && isfield(handles.importedData,'floatY') && ~isempty(handles.importedData.floatY)
        params.r = handles.importedData.floatY(:);
        if isfield(handles.importedData,'fs') && ~isempty(handles.importedData.fs)
            params.fs = handles.importedData.fs;
        end
        params.duration = length(params.r)/params.fs;
    elseif isfield(handles,'generatedR') && ~isempty(handles.generatedR)
        % fallback to legacy generatedR
        params.r = handles.generatedR(:);
        params.duration = length(params.r)/params.fs;
    end

    try
        % install progress callback so run_fxlms can report back
        params.progressFcn = @(frac) updateProgress(frac);
        % reset progress UI
        updateProgress(0);
        % ensure axTL reflects the reference used by the run
        try
            if isfield(params,'r') && ~isempty(params.r)
                axes(handles.axTL); cla(handles.axTL);
                if isfield(handles,'importedData') && isfield(handles.importedData,'t') && numel(handles.importedData.t)==numel(params.r)
                    plot(handles.axTL, handles.importedData.t, params.r, '-k');
                else
                    ttmp = (0:length(params.r)-1)'/params.fs;
                    plot(handles.axTL, ttmp, params.r, '-k');
                end
                grid(handles.axTL,'on'); title(handles.axTL,'Generated reference (preview)'); xlabel('Time (s)'); ylabel('Amplitude');
            end
        catch
        end

        [t,d,y_s,e,W_hist,w,params_out] = run_fxlms(params);
    catch ME
        % ensure progress resets on error
        try updateProgress(0); catch; end
        set(handles.hStatus,'String',['Status: Error - ' ME.message]);
        return;
    end

    % plot to axes
    axes(handles.axTR); cla(handles.axTR);
    plot(t, d, 'k', t, y_s, 'r', t, e, 'b'); legend('d','y_s','e'); xlabel('Time (s)'); ylabel('Amplitude'); grid on;

    axes(handles.axBL); cla(handles.axBL);
    try
        % prefer time axis if available
        if exist('t','var') && numel(t)==numel(d)
            plot(t, 20*log10(abs(hilbert(d))),'k'); hold on;
            plot(t, 20*log10(abs(hilbert(e))),'b'); hold off;
            xlabel(handles.axBL,'Time (s)'); ylabel(handles.axBL,'Level (dB)');
        else
            plot(20*log10(abs(hilbert(d))),'k'); hold on;
            plot(20*log10(abs(hilbert(e))),'b'); hold off;
            xlabel(handles.axBL,'Sample index'); ylabel(handles.axBL,'Level (dB)');
        end
        legend('d level','e level'); grid on;
    catch
        % fallback: simple plot
        plot(20*log10(abs(hilbert(d))),'k'); legend('d level'); grid on;
    end

    axes(handles.axBR); cla(handles.axBR);
    % Show final filter weights as a stem plot (tap index vs amplitude)
    try
        if exist('w','var') && ~isempty(w)
            stem(handles.axBR, 1:length(w), w, '.');
            xlabel(handles.axBR,'Tap index'); ylabel(handles.axBR,'Amplitude');
            title(handles.axBR,'Final weights (w)'); grid(handles.axBR,'on');
        else
            text(0.5,0.5,'No weights available','Parent',handles.axBR,'HorizontalAlignment','center');
        end
    catch
        text(0.5,0.5,'Error plotting weights','Parent',handles.axBR,'HorizontalAlignment','center');
    end
    % store last run results into handles for export/inspection
    try
        handles.lastRun = struct();
        handles.lastRun.t = t;
        handles.lastRun.d = d;
        handles.lastRun.y_s = y_s;
        handles.lastRun.e = e;
        handles.lastRun.W_hist = W_hist;
        handles.lastRun.w = w;
        handles.lastRun.params = params_out;
        guidata(fig, handles);
    catch
        % ignore storage errors
    end

    set(handles.hStatus,'String','Status: Completed'); drawnow;
    try updateProgress(1); catch; end
end

% Unified helper to populate the canonical importedData structure and update preview
function handleImportedDataLocal(y, fs, srcName, meta, sourceType)
    handles = guidata(fig);
    try
        y = y(:);
        if isempty(fs) || isnan(fs) || fs<=0
            fsUse = 48000;
        else
            fsUse = fs;
        end

        imp = handles.importedData;
        imp.floatY = y;
        imp.fs = fsUse;
        imp.t = (0:length(y)-1)'/fsUse;
        imp.intVals = [];
        imp.fileName = srcName;
        imp.Nbits = 24;
        imp.frac = 0;
        imp.encodeType = 'Q';
        imp.meta = meta;
        imp.sourceType = sourceType;
        imp.encodeParams = struct('Nbits',imp.Nbits,'frac',imp.frac,'encodeType',imp.encodeType);

        handles.importedData = imp;
        guidata(fig, handles);

        % update preview in top-left axis if available
        try
            if isfield(handles,'axTL') && ishandle(handles.axTL)
                axes(handles.axTL); cla(handles.axTL);
                plot(handles.axTL, imp.t, imp.floatY, '-k'); grid on;
                title(handles.axTL, 'Generated reference (preview)'); xlabel('Time (s)'); ylabel('Amplitude');
            end
        catch
        end
    catch ME
        rethrow(ME);
    end
end

% Stop functionality removed (Stop button no longer present)

function onGenerate(~,~)
    % Generate reference noise according to UI settings and preview it
    handles = guidata(fig);
    set(handles.hStatus,'String','Status: Generating reference...'); drawnow;
    % Determine selected signal type from the signal popup (mirror of top selector)
    if isfield(handles,'hSignal') && ishandle(handles.hSignal)
        sigList = get(handles.hSignal,'String'); sigType = lower(sigList{get(handles.hSignal,'Value')});
    else
        noiseList = get(handles.hNoise,'String'); sigType = lower(noiseList{get(handles.hNoise,'Value')});
    end
    noiseFile = get(handles.hNoiseFile,'String');
    fs = str2double(get(handles.hFs,'String'));
    duration = str2double(get(handles.hDuration,'String'));
    N = max(1, round(duration * fs));

    try
        switch sigType
            case 'sine'
                % read freq/amp/phase from dynamic controls if present
                % support scalar or array input (e.g. "[500 1000]" or "500,1000")
                if isfield(handles,'hSigFreq') && ishandle(handles.hSigFreq)
                    fstr = get(handles.hSigFreq,'String');
                else
                    fstr = '1000';
                end
                if isfield(handles,'hSigAmp') && ishandle(handles.hSigAmp)
                    Astr = get(handles.hSigAmp,'String');
                else
                    Astr = '1';
                end
                if isfield(handles,'hSigPhase') && ishandle(handles.hSigPhase)
                    pstr = get(handles.hSigPhase,'String');
                else
                    pstr = '0';
                end

                % parse numeric arrays from strings (accept commas/spaces/brackets)
                try
                    fvec = str2num(strrep(fstr,',',' ')); %#ok<ST2NM>
                    if isempty(fvec), fvec = str2double(fstr); end
                catch
                    fvec = str2double(fstr);
                end
                try
                    Avec = str2num(strrep(Astr,',',' ')); %#ok<ST2NM>
                    if isempty(Avec), Avec = str2double(Astr); end
                catch
                    Avec = str2double(Astr);
                end
                try
                    pvec = str2num(strrep(pstr,',',' ')); %#ok<ST2NM>
                    if isempty(pvec), pvec = str2double(pstr); end
                catch
                    pvec = str2double(pstr);
                end

                if isempty(fvec), fvec = 1000; end
                if isempty(Avec), Avec = 1; end
                if isempty(pvec), pvec = 0; end

                % normalize vector shapes (row vectors) and broadcast scalars
                fvec = reshape(fvec,1,[]); Avec = reshape(Avec,1,[]); pvec = reshape(pvec,1,[]);
                nComp = max([numel(fvec), numel(Avec), numel(pvec)]);
                if numel(fvec)==1, fvec = repmat(fvec,1,nComp); end
                if numel(Avec)==1, Avec = repmat(Avec,1,nComp); end
                if numel(pvec)==1, pvec = repmat(pvec,1,nComp); end

                tvec = (0:N-1)'/fs;
                r = zeros(N,1);
                for k=1:nComp
                    r = r + Avec(k) * sin(2*pi*fvec(k)*tvec + pvec(k)*pi/180);
                end
            case 'square'
                if isfield(handles,'hSigFreq')
                    f0 = str2double(get(handles.hSigFreq,'String'));
                else
                    f0 = 1000;
                end
                if isfield(handles,'hSigDuty')
                    duty = str2double(get(handles.hSigDuty,'String'));
                else
                    duty = 50;
                end
                tvec = (0:N-1)'/fs;
                % use square from Signal Processing Toolbox if available, else simple sign(sin)
                try
                    r = square(2*pi*f0*tvec, duty)';
                catch
                    r = sign(sin(2*pi*f0*tvec));
                end
                % ensure column
                r = r(:);
            case 'band-limited'
                % band-limited white noise
                lo = 200; hi = 2000;
                if isfield(handles,'hSigLow'), lo = str2double(get(handles.hSigLow,'String')); end
                if isfield(handles,'hSigHigh'), hi = str2double(get(handles.hSigHigh,'String')); end
                r0 = randn(N,1);
                bp = fir1(512, [lo hi]/(fs/2), 'bandpass');
                r = filter(bp, 1, r0);
            case 'from file'
                if exist(noiseFile,'file')
                    if endsWith(noiseFile,'.bin','IgnoreCase',true)
                        r = readFromBIN(noiseFile); r = r(:);
                    else
                        [r, rfs] = audioread(noiseFile);
                        if exist('rfs','var') && rfs~=fs, r = resample(r, fs, rfs); end
                    end
                    if length(r) < N
                        N = length(r);
                        r = r(1:N);
                    else
                        r = r(1:N);
                    end
                else
                    error('Noise file not found: %s', noiseFile);
                end
            otherwise
                error('Unknown signal type: %s', sigType);
        end
        % apply amplitude parameters if present (do not globally normalize by RMS)
        try
            % For sine, amplitude is handled per-component earlier.
            % Apply amplitude control here only for non-sine signal types
            if ~strcmpi(sigType,'sine')
                if isfield(handles,'hSigAmp') && ishandle(handles.hSigAmp)
                    Auser = str2double(get(handles.hSigAmp,'String'));
                    if ~isnan(Auser)
                        r = r * Auser;
                    end
                end
            end
        catch
            % ignore amplitude application errors
        end

        % store generated reference for Run to reuse (kept for backward compatibility)
        handles.generatedR = r;
        handles.generatedT = (0:length(r)-1)'/fs;

        % Use unified handler to populate canonical importedData (so Generate and Import share state)
        try
            handleImportedDataLocal(r, fs, 'generated_reference', struct('source','generated','noiseType',sigType), 'generated');
            handles = guidata(fig);
        catch
            % fallback to storing directly on handles if helper fails
            handles.importedData.floatY = r(:);
            handles.importedData.t = handles.generatedT;
            handles.importedData.fs = fs;
            handles.importedData.intVals = [];
            handles.importedData.fileName = 'generated_reference';
            handles.importedData.Nbits = 24;
            handles.importedData.frac = 0;
            handles.importedData.encodeType = 'Q';
            handles.importedData.meta = struct('source','generated','noiseType',sigType);
            handles.importedData.sourceType = 'generated';
            guidata(fig, handles);
        end

        % preview generated reference in top-left axes — prefer canonical importedData
        handles = guidata(fig);
        imp = [];
        try
            if isfield(handles,'importedData'), imp = handles.importedData; end
        catch
            imp = [];
        end
        axes(handles.axTL); cla(handles.axTL);
        try
            if ~isempty(imp) && isfield(imp,'floatY') && ~isempty(imp.floatY) && isfield(imp,'t') && ~isempty(imp.t)
                plot(handles.axTL, imp.t, imp.floatY, '-k');
            else
                % fallback to legacy generatedR/time if available
                if isfield(handles,'generatedR') && ~isempty(handles.generatedR)
                    t_fallback = (0:length(handles.generatedR)-1)'/fs;
                    plot(handles.axTL, t_fallback, handles.generatedR, '-k');
                else
                    % nothing to plot
                end
            end
            grid on;
            title(handles.axTL, 'Generated reference (preview)'); xlabel('Time (s)'); ylabel('Amplitude');
        catch
            % ignore plotting errors
        end
        % Clear previous run results so the four panes reflect current data after Generate
        try
            if isfield(handles,'axTR') && ishandle(handles.axTR), cla(handles.axTR); end
            if isfield(handles,'axBL') && ishandle(handles.axBL), cla(handles.axBL); end
            if isfield(handles,'axBR') && ishandle(handles.axBR), cla(handles.axBR); end
        catch
        end

        set(handles.hStatus,'String',sprintf('Status: Generated reference (%d samples) — available as importedData', length(r)));
    catch ME
        set(handles.hStatus,'String',['Status: Generate error - ' ME.message]);
    end
end

function onSignalTypeChanged(~,~)
    % Dynamically populate controls in the signalPanel based on selected type
    handles = guidata(fig);
    % prefer inner popup if available
    % always use the top-level selector (`hNoise`) as the single source of truth
    sel = get(handles.hNoise,'Value');
    opts = get(handles.hNoise,'String');
    sigType = lower(opts{sel});

    % delete existing dynamic controls (panel will be repopulated)
    kids = get(handles.signalPanel,'Children');
    try delete(kids); catch; end

    % create controls for each type
    switch sigType
        case 'sine'
            % Amplitude on top, then Frequency, then Phase
            uicontrol('Parent',handles.signalPanel,'Style','text','Units','normalized','Position',[0.03 0.70 0.45 0.18],'String','Amplitude:','HorizontalAlignment','left');
            hAmp = uicontrol('Parent',handles.signalPanel,'Style','edit','Units','normalized','Position',[0.52 0.70 0.40 0.18],'String','1');
            uicontrol('Parent',handles.signalPanel,'Style','text','Units','normalized','Position',[0.03 0.44 0.45 0.18],'String','Frequency (Hz):','HorizontalAlignment','left');
            hFreq = uicontrol('Parent',handles.signalPanel,'Style','edit','Units','normalized','Position',[0.52 0.44 0.40 0.18],'String','1000');
            uicontrol('Parent',handles.signalPanel,'Style','text','Units','normalized','Position',[0.03 0.18 0.45 0.18],'String','Phase (deg):','HorizontalAlignment','left');
            hPhase = uicontrol('Parent',handles.signalPanel,'Style','edit','Units','normalized','Position',[0.52 0.18 0.40 0.18],'String','0');
            handles.hSigFreq = hFreq; handles.hSigAmp = hAmp; handles.hSigPhase = hPhase;
        case 'square'
            % Amplitude on top, then Frequency, then Duty
            uicontrol('Parent',handles.signalPanel,'Style','text','Units','normalized','Position',[0.03 0.70 0.45 0.18],'String','Amplitude:','HorizontalAlignment','left');
            hAmp = uicontrol('Parent',handles.signalPanel,'Style','edit','Units','normalized','Position',[0.52 0.70 0.40 0.18],'String','1');
            uicontrol('Parent',handles.signalPanel,'Style','text','Units','normalized','Position',[0.03 0.44 0.45 0.18],'String','Frequency (Hz):','HorizontalAlignment','left');
            hFreq = uicontrol('Parent',handles.signalPanel,'Style','edit','Units','normalized','Position',[0.52 0.44 0.40 0.18],'String','1000');
            uicontrol('Parent',handles.signalPanel,'Style','text','Units','normalized','Position',[0.03 0.18 0.45 0.18],'String','Duty (%):','HorizontalAlignment','left');
            hDuty = uicontrol('Parent',handles.signalPanel,'Style','edit','Units','normalized','Position',[0.52 0.18 0.40 0.18],'String','50');
            handles.hSigFreq = hFreq; handles.hSigDuty = hDuty;
            handles.hSigAmp = hAmp;
        case 'band-limited'
            % Amplitude on top, then Low cut, then High cut
            uicontrol('Parent',handles.signalPanel,'Style','text','Units','normalized','Position',[0.03 0.70 0.45 0.18],'String','Amplitude:','HorizontalAlignment','left');
            hAmpBL = uicontrol('Parent',handles.signalPanel,'Style','edit','Units','normalized','Position',[0.52 0.70 0.40 0.18],'String','1');
            uicontrol('Parent',handles.signalPanel,'Style','text','Units','normalized','Position',[0.03 0.44 0.45 0.18],'String','Low cut (Hz):','HorizontalAlignment','left');
            hLow = uicontrol('Parent',handles.signalPanel,'Style','edit','Units','normalized','Position',[0.52 0.44 0.40 0.18],'String','200');
            uicontrol('Parent',handles.signalPanel,'Style','text','Units','normalized','Position',[0.03 0.18 0.45 0.18],'String','High cut (Hz):','HorizontalAlignment','left');
            hHigh = uicontrol('Parent',handles.signalPanel,'Style','edit','Units','normalized','Position',[0.52 0.18 0.40 0.18],'String','2000');
            handles.hSigLow = hLow; handles.hSigHigh = hHigh;
            handles.hSigAmp = hAmpBL;
        case 'from file'
            % Provide amplitude control first for from-file case so user can scale imported waveform
            uicontrol('Parent',handles.signalPanel,'Style','text','Units','normalized','Position',[0.03 0.70 0.45 0.18],'String','Amplitude:','HorizontalAlignment','left');
            hAmpFile = uicontrol('Parent',handles.signalPanel,'Style','edit','Units','normalized','Position',[0.52 0.70 0.40 0.18],'String','1');
            handles.hSigAmp = hAmpFile;
        otherwise
            % nothing
    end
    guidata(fig,handles);
end

function updateProgress(frac)
    % Nested helper to update progress bar (frac in [0,1])
    try
        handles = guidata(fig);
        if isempty(handles) || ~isfield(handles,'hProgFill')
            return;
        end
        % clamp
        frac = max(0,min(1,frac));
        % set rectangle width in axes coordinates [0..1]
        set(handles.hProgFill,'Position',[0 0 frac 1]);
        if frac>=1
            set(handles.hProgText,'String','Completed');
        else
            set(handles.hProgText,'String',sprintf('%d%%',round(frac*100)));
        end
        drawnow;
    catch
    end
end

function onExport(~,~)
    % If generated/imported data exists, open export dialog as in signal_generator_gui
    handles = guidata(fig);
    if isfield(handles,'importedData') && ~isempty(handles.importedData) && ~isempty(handles.importedData.floatY)
        % For now, simply save the floating waveform to a .mat or .csv via uiputfile
        [fileName, filePath] = uiputfile({'*.mat','MAT file (*.mat)';'*.csv','CSV file (*.csv)'}, 'Export generated data');
        if isequal(fileName,0), set(handles.hStatus,'String','Export cancelled'); return; end
        full = fullfile(filePath,fileName);
        [~,~,ext] = fileparts(full);
        if strcmpi(ext,'.mat')
            % build a comprehensive struct with imported data and last run results (if available)
            S = struct();
            S.importedData = handles.importedData;
            % include generated reference if present
            try
                if isfield(handles,'generatedR'), S.generatedR = handles.generatedR; end
                if isfield(handles,'generatedT'), S.generatedT = handles.generatedT; end
            catch
            end
            % include last run results (t,d,y_s,e,W_hist,w,params)
            try
                if isfield(handles,'lastRun') && ~isempty(handles.lastRun)
                    S.lastRun = handles.lastRun;
                end
            catch
            end
            % include handles-level parameters used for run
            try
                S.guiParams = struct('Lw', get(handles.hLw,'String'), 'mu', get(handles.hMu,'String'), 'fs', get(handles.hFs,'String'), 'duration', get(handles.hDuration,'String'));
            catch
                S.guiParams = [];
            end
            save(full,'-struct','S');
        else
            % CSV export remains single-column float waveform for compatibility
            csvwrite(full, handles.importedData.floatY);
        end
        set(handles.hStatus,'String',['Exported to ' full]);
    else
        msgbox('No generated/imported data available to export','Info','modal');
    end
end

function onBrowse(~,~)
    % Browse for a noise file, update the path display and try to load it
    handles = guidata(fig);
    startPath = fullfile(pwd,'data');
    [fileName, filePath] = uigetfile({'*.bin;*.csv;*.wav;*.mat','Supported files (*.bin,*.csv,*.wav,*.mat)';'*.*','All files'}, 'Select noise file', startPath);
    if isequal(fileName,0)
        set(handles.hStatus,'String','Status: Browse cancelled');
        return;
    end

    fullFile = fullfile(filePath, fileName);
    % update path display (read-only text control)
    try
        set(handles.hNoiseFile,'String', fullFile);
    catch
        % if handle missing for any reason, ignore but continue
    end
    drawnow;

    % attempt to read the file into importedData for downstream export/preview
    try
        [~,~,ext] = fileparts(fullFile);
        fs = str2double(get(handles.hFs,'String'));
        switch lower(ext)
            case '.bin'
                if exist('readFromBIN','file')
                    y = readFromBIN(fullFile);
                else
                    error('readFromBIN not available on path');
                end
            case '.csv'
                if exist('readFromCSV','file')
                    y = readFromCSV(fullFile);
                else
                    y = csvread(fullFile);
                end
            case '.wav'
                [y, rfs] = audioread(fullFile);
                if exist('rfs','var') && ~isempty(rfs) && rfs~=fs
                    y = resample(y, fs, rfs);
                end
            case '.mat'
                S = load(fullFile);
                % pick the first numeric vector variable
                vars = fieldnames(S);
                y = [];
                for k=1:numel(vars)
                    v = S.(vars{k});
                    if isnumeric(v) && isvector(v)
                        y = v(:);
                        break;
                    end
                end
                if isempty(y)
                    error('No suitable vector found in MAT file');
                end
            otherwise
                % fallback: try audioread then csvread
                try
                    [y, rfs] = audioread(fullFile);
                    if exist('rfs','var') && ~isempty(rfs) && rfs~=fs, y = resample(y, fs, rfs); end
                catch
                    y = csvread(fullFile);
                end
        end

        y = y(:);
        % Use unified handler to populate importedData
        try
            handleImportedDataLocal(y, fs, fullFile, struct('source','file','origExt',ext), 'imported_file');
            handles = guidata(fig);
            set(handles.hStatus,'String',sprintf('Status: Loaded %s (%d samples)', fileName, length(y)));
        catch ME
            % fallback: store directly
            handles.importedData.floatY = y;
            handles.importedData.t = (0:length(y)-1)'/fs;
            handles.importedData.fs = fs;
            handles.importedData.intVals = [];
            handles.importedData.fileName = fullFile;
            handles.importedData.Nbits = 24;
            handles.importedData.frac = 0;
            handles.importedData.encodeType = 'Q';
            handles.importedData.meta = struct('source','file','origExt',ext);
            handles.importedData.sourceType = 'imported_file';
            guidata(fig, handles);
            set(handles.hStatus,'String',sprintf('Status: Loaded %s (%d samples)', fileName, length(y)));
        end
    catch ME
        set(handles.hStatus,'String',['Status: Load error - ' ME.message]);
    end
end

end

function onExportToWorkspace(src,~)
    % Export current imported/generated data and last run to base workspace
    fig = ancestor(src,'figure');
    handles = guidata(fig);
    % Export key run variables directly to base workspace (not a struct)
    try
        % collect available items
        % prefer lastRun when present
        if isfield(handles,'lastRun') && ~isempty(handles.lastRun)
            lr = handles.lastRun;
        else
            lr = struct();
        end

        % t (time vector)
        if isfield(lr,'t') && ~isempty(lr.t)
            t = lr.t;
        elseif isfield(handles,'generatedT') && ~isempty(handles.generatedT)
            t = handles.generatedT;
        elseif isfield(handles,'importedData') && isfield(handles.importedData,'t') && ~isempty(handles.importedData.t)
            t = handles.importedData.t;
        else
            % try to synthesize t from available signals
            if isfield(lr,'d') && ~isempty(lr.d) && isfield(handles,'hFs')
                fs_tmp = str2double(get(handles.hFs,'String'));
                t = (0:length(lr.d)-1)'/max(1,fs_tmp);
            else
                t = [];
            end
        end

        % d, y_s, e, W_hist/w
        if isfield(lr,'d'), d = lr.d; end
        if isfield(lr,'y_s'), y_s = lr.y_s; end
        if isfield(lr,'e'), e = lr.e; end
        if isfield(lr,'W_hist'), W_hist = lr.W_hist; end
        if isfield(lr,'w'), w = lr.w; end

        % GUI params: fs, mu, Lw
        try fs = str2double(get(handles.hFs,'String')); catch, fs = []; end
        try mu = str2double(get(handles.hMu,'String')); catch, mu = []; end
        try Lw = str2double(get(handles.hLw,'String')); catch, Lw = []; end

        % Export to base workspace: assign only existing variables
        exported = {};
        try
            if exist('d','var'), assignin('base','d',d); exported{end+1}='d'; end
            if exist('y_s','var'), assignin('base','y_s',y_s); exported{end+1}='y_s'; end
            if exist('e','var'), assignin('base','e',e); exported{end+1}='e'; end
            if exist('w','var'), assignin('base','w',w); exported{end+1}='w'; end
            if exist('W_hist','var'), assignin('base','W_hist',W_hist); exported{end+1}='W_hist'; end
            if ~isempty(t), assignin('base','t',t); exported{end+1}='t'; end
            if ~isempty(fs), assignin('base','fs',fs); exported{end+1}='fs'; end
            if ~isempty(mu), assignin('base','mu',mu); exported{end+1}='mu'; end
            if ~isempty(Lw), assignin('base','Lw',Lw); exported{end+1}='Lw'; end

            if isempty(exported)
                set(handles.hStatus,'String','Export to workspace: nothing available to export');
            else
                set(handles.hStatus,'String',['Exported variables to base workspace: ' strjoin(exported,', ')]);
            end
        catch ME
            set(handles.hStatus,'String',['Export to workspace failed: ' ME.message]);
        end
    catch ME
        set(handles.hStatus,'String',['Export to workspace error: ' ME.message]);
    end
end

function onSysidPrimaryBrowse(src,~)
    % Browse for a primary LMS_SYSID*prim*.mat file and update edit box
    fig = ancestor(src,'figure');
    handles = guidata(fig);
    startPath = fullfile(pwd,'data');
    [fileName, filePath] = uigetfile({'*.mat','MAT files (*.mat)'}, 'Select primary LMS_SYSID*prim*.mat', startPath);
    if isequal(fileName,0)
        set(handles.hStatus,'String','Primary SysID selection cancelled'); return;
    end
    fullFile = fullfile(filePath, fileName);
    try set(handles.hSysidPrimaryFile,'String', fullFile); catch; end
    try set(handles.hStatus,'String',['Primary SysID file: ' fullFile]); drawnow; catch; end
end

function onSysidSecondaryBrowse(src,~)
    % Browse for a secondary LMS_SYSID*.mat file and update edit box
    fig = ancestor(src,'figure');
    handles = guidata(fig);
    startPath = fullfile(pwd,'data');
    [fileName, filePath] = uigetfile({'*.mat','MAT files (*.mat)'}, 'Select secondary LMS_SYSID*.mat', startPath);
    if isequal(fileName,0)
        set(handles.hStatus,'String','Secondary SysID selection cancelled'); return;
    end
    fullFile = fullfile(filePath, fileName);
    try set(handles.hSysidSecondaryFile,'String', fullFile); catch; end
    try set(handles.hStatus,'String',['Secondary SysID file: ' fullFile]); drawnow; catch; end
end