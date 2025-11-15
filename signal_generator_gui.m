function signal_generator_gui()
% SIGNAL_GENERATOR_GUI  Simple MATLAB GUI to generate signals and export
% as fixed-point encoded .hex, .mem, or .bin files.
%
% Usage: run the file or call `signal_generator_gui` from MATLAB.
%
% Features:
% - Choose signal: Sine, Square, PRBS
% - Signal-specific parameters appear dynamically
% - Choose fixed-point encoding: Unsigned, Signed(2's), Q-format
% - Export to .hex, .mem (text hex per line), or .bin (raw bytes)

% Create main figure
hFig = figure('Name','Signal Generator','NumberTitle','off', 'MenuBar','none', ...
    'ToolBar','none','Position',[300 200 1200 800]);

% Layout: top controls, left parameters panel, right encoding panel, big axes below
% Top: Signal & Fixed-format selectors
uicontrol('Parent',hFig,'Style','text','String','Signal:','Units','normalized',...
    'Position',[0.02 0.94 0.12 0.04],'HorizontalAlignment','left','FontSize',10);
hSignal = uicontrol('Parent',hFig,'Style','popupmenu','String',{'Sine','Square','White Noise','PRBS'}, ...
    'Units','normalized','Position',[0.14 0.94 0.28 0.04],'Callback',@signalChanged,'FontSize',10);

uicontrol('Parent',hFig,'Style','text','String','Sign:','Units','normalized',...
    'Position',[0.46 0.94 0.04 0.04],'HorizontalAlignment','left','FontSize',10);
hSignType = uicontrol('Parent',hFig,'Style','popupmenu', ...
    'String',{'Unsigned','Signed (Two''s complement)'},...
    'Units','normalized','Position',[0.50 0.94 0.18 0.04],'Callback',@encodeChanged,'FontSize',10,'Value',2);
uicontrol('Parent',hFig,'Style','text','String','Numeric format:','Units','normalized',...
    'Position',[0.70 0.94 0.10 0.04],'HorizontalAlignment','left','FontSize',10);
hNumType = uicontrol('Parent',hFig,'Style','popupmenu', ...
    'String',{'Integer (N bits)','Q format (N bits, frac)'},...
    'Units','normalized','Position',[0.80 0.94 0.18 0.04],'Callback',@encodeChanged,'FontSize',10,'Value',2);

% Left parameters panel (large)
hParamPanel = uipanel('Parent',hFig,'Title','Parameters','Units','normalized',...
    'Position',[0.02 0.55 0.46 0.37],'FontSize',10);

% Right encoding panel to show encoding params nicely 
hEncodePanel = uipanel('Parent',hFig,'Title','Encoding Params','Units','normalized',...
    'Position',[0.50 0.62 0.48 0.26],'FontSize',10);

% Interaction controls (Zoom / Pan / Data Cursor / Reset / Save)
btnZoom = uicontrol('Parent',hFig,'Style','togglebutton','String','Zoom','Units','normalized',...
    'Position',[0.50 0.565 0.055 0.035],'Callback',@toggleZoom,'FontSize',9);
btnPan = uicontrol('Parent',hFig,'Style','togglebutton','String','Pan','Units','normalized',...
    'Position',[0.56 0.565 0.055 0.035],'Callback',@togglePan,'FontSize',9);
btnData = uicontrol('Parent',hFig,'Style','togglebutton','String','Data Cursor','Units','normalized',...
    'Position',[0.62 0.565 0.085 0.035],'Callback',@toggleDataCursor,'FontSize',9);
uicontrol('Parent',hFig,'Style','pushbutton','String','Reset View','Units','normalized',...
    'Position',[0.71 0.565 0.07 0.035],'Callback',@resetView,'FontSize',9);
uicontrol('Parent',hFig,'Style','pushbutton','String','Save Fig','Units','normalized',...
    'Position',[0.79 0.565 0.09 0.035],'Callback',@saveFigure,'FontSize',9);

% (Export Format moved to bottom next to action buttons)

% Big axes below
hAx = axes('Parent',hFig,'Units','normalized','Position',[0.05 0.14 0.90 0.36]);
title(hAx,'Preview');
xlabel(hAx,'Time (s)');
ylabel(hAx,'Amplitude');

% hStatus = uicontrol('Parent',hFig,'Style','text','String','Ready','Units','normalized',...
%     'Position',[0.05 0.10 0.90 0.03],'HorizontalAlignment','left');
% Status bar
hStatus = uicontrol('Parent',hFig,'Style','text','String','Ready','Units','normalized',...
    'Position',[0.04 0.07 0.96 0.02],'HorizontalAlignment','left','FontSize',9);

% Bottom action buttons
uicontrol('Parent',hFig,'Style','pushbutton','String','Generate & Preview','Units','normalized',...
    'Position',[0.12 0.02 0.12 0.04],'Callback',@generatePreview,'FontSize',10);
% Import button (between Generate and Export)
uicontrol('Parent',hFig,'Style','pushbutton','String','Import...','Units','normalized',...
    'Position',[0.30 0.02 0.12 0.04],'Callback',@importCallback,'FontSize',10);
uicontrol('Parent',hFig,'Style','pushbutton','String','Export...','Units','normalized',...
    'Position',[0.48 0.02 0.12 0.04],'Callback',@exportCallback,'FontSize',10);
uicontrol('Parent',hFig,'Style','pushbutton','String','Import from Workspace','Units','normalized',...
    'Position',[0.66 0.02 0.12 0.04],'Callback',@importFromWorkspaceCallback,'FontSize',10);
uicontrol('Parent',hFig,'Style','pushbutton','String','Export to Workspace','Units','normalized',...
    'Position',[0.84 0.02 0.12 0.04],'Callback',@exportToWorkspaceCallback,'FontSize',10);

% Initialize default parameter controls
currentParams = struct();
createParamControls('Sine');
createEncodeControls();

% storage for imported data
importedData.intVals = [];
importedData.fileName = '';
importedData.Nbits = [];

% No dragging in the new layout

% ----------------- Nested functions -----------------
function signalChanged(~,~)
    val = hSignal.String{hSignal.Value};
    createParamControls(val);
end

function encodeChanged(~,~)
    % Called when either numeric type or sign selection changes
    createEncodeControls();
end

% (splitter drag functions removed for fixed layout)

function createParamControls(signalType)
    delete(get(hParamPanel,'Children'));
    switch lower(signalType)
        case 'sine'
            % Consistent spacing: Amplitude, Offset, Frequency, Phase, Duration, SampleRate
            addLabelEdit(hParamPanel,'Amplitude','1',0.78);
            addLabelEdit(hParamPanel,'Offset','0',0.65);
            addLabelEdit(hParamPanel,'Frequency (Hz)','50',0.52);
            addLabelEdit(hParamPanel,'Phase (deg)','0',0.39);
            hDur = addLabelEdit(hParamPanel,'Duration (s)','10',0.26,'duration');
            hSRate = addLabelEdit(hParamPanel,'Sample Rate (Hz)','48000',0.13,'srate');
            set([hDur,hSRate],'Callback',@syncTimeSamples);
        case 'square'
            % Consistent spacing: Amplitude, Offset, Frequency, Duty, Duration, SampleRate
            addLabelEdit(hParamPanel,'Amplitude','1',0.78);
            addLabelEdit(hParamPanel,'Offset','0',0.65);
            addLabelEdit(hParamPanel,'Frequency (Hz)','50',0.52);
            addLabelEdit(hParamPanel,'Duty (%)','50',0.39);
            hDur = addLabelEdit(hParamPanel,'Duration (s)','10',0.26,'duration');
            hSRate = addLabelEdit(hParamPanel,'Sample Rate (Hz)','48000',0.13,'srate');
            set([hDur,hSRate],'Callback',@syncTimeSamples);
        case 'prbs'
            % Consistent spacing (7 rows): Amplitude, Order, Seed, Offset, Duration, SampleRate, Taps
            addLabelEdit(hParamPanel,'Amplitude','1',0.88,'prbs_amp');
            addLabelEdit(hParamPanel,'Order (e.g. 13)','13',0.76,'prbs_order');
            % generate a reasonably random default seed at GUI creation
            try
                randSeed = randi(2^31-1);
            catch
                randSeed = floor(sum(100*clock));
            end
            addLabelEdit(hParamPanel,'Seed (integer)',num2str(randSeed),0.64,'prbs_seed');
            addLabelEdit(hParamPanel,'Offset','0',0.52);
            hDur = addLabelEdit(hParamPanel,'Duration (s)','10',0.40,'duration');
            hfs = addLabelEdit(hParamPanel,'Sample Rate (Hz)','48000',0.28,'prbs_fs');
            set([hDur,hfs],'Callback',@syncTimeSamples);
            addLabelEdit(hParamPanel,'Polynom taps (comma)','[13 11]',0.16,'prbs_taps');
        case 'white noise'
            % Parameters: Amplitude, Duration, SampleRate, Low cutoff, High cutoff, FIR order
            addLabelEdit(hParamPanel,'Amplitude','1',0.78);
            hDur = addLabelEdit(hParamPanel,'Duration (s)','10',0.66,'duration');
            hSRate = addLabelEdit(hParamPanel,'Sample Rate (Hz)','48000',0.54,'srate');
            addLabelEdit(hParamPanel,'Low Cutoff (Hz)','20',0.42);
            addLabelEdit(hParamPanel,'High Cutoff (Hz)','20000',0.30);
            addLabelEdit(hParamPanel,'FIR order (even)','128',0.18);
            set([hDur,hSRate],'Callback',@syncTimeSamples);
    end
end

function hEdit = addLabelEdit(parent,labelStr,defaultY,yy,tag)
    % helper: add label and edit uicontrols inside a parent in normalized coords
    % tag is optional; if provided, set the edit's Tag property for later lookup
    if nargin<5
        tag = '';
    end
    uicontrol('Parent',parent,'Style','text','String',labelStr, ...
        'Units','normalized','Position',[0.03 yy 0.45 0.08],'HorizontalAlignment','left','FontSize',10);
    % create a sane tag if not provided
    if isempty(tag)
        tag = labelStr;
        tag = lower(tag);
        tag = regexprep(tag,'[^a-z0-9]','_');
        tag = regexprep(tag,'_+','_');
    end
    params = {'Parent',parent,'Style','edit','String',defaultY,'Units','normalized', ...
        'Position',[0.55 yy 0.42 0.08],'Tag',tag,'FontSize',10};
    hEdit = uicontrol(params{:});
end

function createEncodeControls()
    delete(get(hEncodePanel,'Children'));
    % read numeric and sign selections
    try
        numOpts = get(hNumType,'String'); numVal = get(hNumType,'Value');
        numSel = numOpts{numVal};
    catch
        numSel = 'Q format (N bits, frac)';
    end
    try
        signOpts = get(hSignType,'String'); signVal = get(hSignType,'Value');
        signSel = signOpts{signVal};
    catch
        signSel = 'Signed (Two''s complement)';
    end

    % Common N bits field
    uicontrol('Parent',hEncodePanel,'Style','text','String','N bits (total):','Units','normalized',...
        'Position',[0.03 0.66 0.38 0.16],'HorizontalAlignment','left','FontSize',10);
    hNedit = uicontrol('Parent',hEncodePanel,'Style','edit','String','24','Units','normalized','Position',[0.52 0.66 0.16 0.16],'Tag','enc_nbits','Callback',@encNChanged,'FontSize',10);

    if contains(numSel,'Q')
        % show frac bits popup
        uicontrol('Parent',hEncodePanel,'Style','text','String','Frac bits:','Units','normalized',...
            'Position',[0.03 0.36 0.38 0.16],'HorizontalAlignment','left','FontSize',10);
        Ndefault = 24;
        fracOpts = arrayfun(@num2str, (Ndefault-1):-1:0, 'UniformOutput', false);
        uicontrol('Parent',hEncodePanel,'Style','popupmenu','String',fracOpts,'Units','normalized',...
            'Position',[0.52 0.36 0.16 0.16],'Tag','enc_frac','Value',1,'FontSize',10);
        mapStr = 'Mapping: use provided Q format, signal is scaled by 2^frac (two''s complement)';
    else
        % integer type: no frac
        uicontrol('Parent',hEncodePanel,'Style','text','String','Frac bits: (not used)','Units','normalized',...
            'Position',[0.03 0.36 0.38 0.16],'HorizontalAlignment','left','FontSize',9);
        uicontrol('Parent',hEncodePanel,'Style','text','String',' ','Units','normalized',...
            'Position',[0.52 0.36 0.16 0.16],'HorizontalAlignment','left','FontSize',9,'Tag','enc_frac');
        if contains(signSel,'Unsigned')
            mapStr = 'Mapping: signal normalized to [-1,1] then to unsigned [0,2^N-1]';
        else
            mapStr = 'Mapping: signal normalized to [-1,1] then to signed two''s complement';
        end
    end
    uicontrol('Parent',hEncodePanel,'Style','text','String',mapStr,'Units','normalized',...
        'Position',[0.03 0.02 0.92 0.12],'HorizontalAlignment','left','FontSize',9);
    % Add a toggle button to enable/disable quantization overlay in preview
    uicontrol('Parent',hEncodePanel,'Style','togglebutton','String','Quantize','Units','normalized',...
        'Position',[0.72 0.66 0.24 0.16],'Tag','btn_quantize','FontSize',10,'Value',0, 'TooltipString','Toggle to overlay quantized waveform on preview');
end


function encNChanged(src,~)
    % Callback when user edits total N bits in encoding panel.
    % Update the frac popup options to 0:(N-1) and keep selection if possible.
    try
        N = str2double(get(src,'String'));
        if isnan(N) || N<1, N = 1; end
        hFrac = findobj(hEncodePanel,'Tag','enc_frac');
        if isempty(hFrac), return; end
        oldOpts = get(hFrac,'String');
        oldVal = get(hFrac,'Value');
        % build new options descending, and try to preserve numeric selection
        newOpts = arrayfun(@num2str, (N-1):-1:0, 'UniformOutput', false);
        % preserve numeric old selection if present
        newVal = 1;
        try
            oldSelStr = oldOpts{oldVal};
            idx = find(strcmp(newOpts, oldSelStr),1);
            if ~isempty(idx)
                newVal = idx;
            else
                newVal = 1; % default to highest frac
            end
        catch
            newVal = 1;
        end
        set(hFrac,'String',newOpts); set(hFrac,'Value',newVal);
    catch
    end
end

function generatePreview(~,~)
    try
        [y, t, info] = generateSignalFromUI();
        % Performance safeguard: truncate preview to at most MAX_PREVIEW_POINTS samples
        Ns_orig = numel(y);
        MAX_PREVIEW_POINTS = 5000; % configurable default
        truncated = false;
        if Ns_orig > MAX_PREVIEW_POINTS
            y = y(1:MAX_PREVIEW_POINTS);
            t = t(1:MAX_PREVIEW_POINTS);
            truncated = true;
        end
        cla(hAx);
        if isfield(info,'type') && strcmpi(info.type,'PRBS')
            stairs(hAx, t, y, '-b');
        else
            plot(hAx, t, y, '-b');
        end
        grid(hAx,'on');
        title(hAx, sprintf('%s (preview)', info.type));
        xlabel(hAx,'Time (s)'); ylabel(hAx,'Amplitude');
            if truncated
                set(hStatus,'String',sprintf('Generated preview (truncated %d->%d samples).', Ns_orig, MAX_PREVIEW_POINTS));
            else
                set(hStatus,'String','Generated preview.');
            end
            % --- Overlay quantized result only if user enabled the Quantize toggle ---
            try
                hBtn = findobj(hEncodePanel,'Tag','btn_quantize');
                doQuant = ~isempty(hBtn) && ishandle(hBtn) && get(hBtn,'Value');
            catch
                doQuant = false;
            end
            if doQuant
                try
                    % read encoding params from the two-popups and fields
                    [encType, N, frac] = getEncodingParams();
                    % encode and reconstruct quantized waveform
                    intQ = encodeSignalToIntegers(y, encType, N, frac);
                    yq = reconstructFromInts(y, double(intQ), encType, N, frac);
                    hold(hAx,'on');
                    % draw quantized waveform (use red, dashed, thinner)
                    if isfield(info,'type') && strcmpi(info.type,'PRBS')
                        stairs(hAx, t, yq, '--r','LineWidth',1.0);
                    else
                        plot(hAx, t, yq, '--r','LineWidth',1.0);
                    end
                    legend(hAx,{'Original','Quantized'},'Location','best');
                    hold(hAx,'off');
                catch
                    % don't let overlay errors break preview
                end
            end
        % 预览后清空导入数据
        importedData.intVals = [];
        importedData.fileName = '';
        importedData.Nbits = [];
    catch ME
        set(hStatus,'String',['Error: ' ME.message]);
    end  
end

function yq = reconstructFromInts(y_orig, intVals, encType, Nbits, frac)
    % Reconstruct floating waveform from encoded integers using same rules as encodeSignalToIntegers
    if contains(encType,'Q')
        % treat as signed Q format
        maxPos = 2^(Nbits-1)-1;
        raw = double(intVals);
        raw(raw>maxPos) = raw(raw>maxPos) - 2^Nbits;
        yq = raw / (2^frac);
    elseif startsWith(encType,'Unsigned')
        % need original normalization factor used during encoding
        if max(abs(y_orig))==0
            scale = 1;
        else
            scale = max(abs(y_orig));
        end
        yNq = (double(intVals) / (2^Nbits-1)) * 2 - 1;
        yq = yNq * scale;
    else
        % Signed two's complement
        maxPos = 2^(Nbits-1)-1;
        raw = double(intVals);
        raw(raw>maxPos) = raw(raw>maxPos) - 2^Nbits;
        if maxPos==0
            yq = zeros(size(raw));
        else
            if max(abs(y_orig))==0
                scale = 1;
            else
                scale = max(abs(y_orig));
            end
            yNq = raw / maxPos;
            yq = yNq * scale;
        end
    end      
end

function [params, cancelled] = askImportParams(meta, ext, source)
    % Unified modal dialog to collect import encoding parameters.
    % If meta provided (non-empty), will use meta and return without prompting.
    % params fields: numericSel, signSel, encodeType, Nbits, frac, vmin, vmax, peak, fs, bps, meta (if used)
    cancelled = false;
    params = struct('numericSel','Integer (N bits)','signSel','Signed (Two''s complement)','encodeType','Signed',...
        'Nbits',24,'frac',0,'vmin',[],'vmax',[],'peak',[],'fs',48000,'bps',[],'meta',[]);
    try
        if ~isempty(meta)
            % populate from metadata and return
            params.meta = meta;
            if isfield(meta,'numericType'), params.numericSel = meta.numericType; end
            if isfield(meta,'numeric_type'), params.numericSel = meta.numeric_type; end
            if isfield(meta,'sign'), params.signSel = meta.sign; end
            if isfield(meta,'signed'), params.signSel = meta.signed; end
            if isfield(meta,'Nbits'), params.Nbits = meta.Nbits; end
            if isfield(meta,'frac'), params.frac = meta.frac; end
            if isfield(meta,'vmin'), params.vmin = meta.vmin; end
            if isfield(meta,'vmax'), params.vmax = meta.vmax; end
            if isfield(meta,'peak'), params.peak = meta.peak; end
            if isfield(meta,'fs'), params.fs = meta.fs; end
            if isfield(meta,'bytes_per_sample'), params.bps = meta.bytes_per_sample; end
            % decide encodeType
            if contains(params.numericSel,'Q')
                params.encodeType = 'Q';
            else
                if contains(params.signSel,'Unsigned')
                    params.encodeType = 'Unsigned';
                else
                    params.encodeType = 'Signed';
                end
            end
            return;
        end
    catch
        % fall through to dialog
    end

    % Build modal dialog for user input
    dpos = get(hFig,'Position');
    figw = 420; figh = 360; fx = dpos(1)+dpos(3)/2-figw/2; fy = dpos(2)+dpos(4)/2-figh/2;
    hDlg = figure('Name','Import Parameters','NumberTitle','off','MenuBar','none','ToolBar','none', ...
        'Position',[fx fy figw figh],'WindowStyle','modal','Resize','off');

    ypos = 1-40/360; gap = 36/360;
    uicontrol('Parent',hDlg,'Style','text','String','Numeric format:','HorizontalAlignment','left','Position',[10 figh-40 160 20]);
    hNum = uicontrol('Parent',hDlg,'Style','popupmenu','String',{'Integer (N bits)','Q format (N bits, frac)'},'Position',[180 figh-44 220 24]);
    uicontrol('Parent',hDlg,'Style','text','String','Sign:','HorizontalAlignment','left','Position',[10 figh-80 160 20]);
    hSign = uicontrol('Parent',hDlg,'Style','popupmenu','String',{'Unsigned','Signed (Two''s complement)'},'Position',[180 figh-84 220 24]);

    % N bits
    uicontrol('Parent',hDlg,'Style','text','String','N bits (total):','HorizontalAlignment','left','Position',[10 figh-120 160 20]);
    hN = uicontrol('Parent',hDlg,'Style','edit','String',num2str(params.Nbits),'Position',[180 figh-124 120 24]);
    % frac (for Q)
    uicontrol('Parent',hDlg,'Style','text','String','Frac bits:','HorizontalAlignment','left','Position',[10 figh-160 160 20],'Tag','lab_frac');
    hFrac = uicontrol('Parent',hDlg,'Style','edit','String',num2str(params.frac),'Position',[180 figh-164 120 24],'Tag','edit_frac');

    % vmin/vmax or peak
    uicontrol('Parent',hDlg,'Style','text','String','vmin (for unsigned):','HorizontalAlignment','left','Position',[10 figh-200 160 20],'Tag','lab_vmin');
    hVmin = uicontrol('Parent',hDlg,'Style','edit','String','-1','Position',[180 figh-204 120 24],'Tag','edit_vmin');
    uicontrol('Parent',hDlg,'Style','text','String','vmax (for unsigned):','HorizontalAlignment','left','Position',[10 figh-240 160 20],'Tag','lab_vmax');
    hVmax = uicontrol('Parent',hDlg,'Style','edit','String','1','Position',[180 figh-244 120 24],'Tag','edit_vmax');

    uicontrol('Parent',hDlg,'Style','text','String','Peak (for signed):','HorizontalAlignment','left','Position',[10 figh-200 160 20],'Visible','off','Tag','lab_peak');
    hPeak = uicontrol('Parent',hDlg,'Style','edit','String','1','Position',[180 figh-204 120 24],'Visible','off','Tag','edit_peak');

    % fs
    uicontrol('Parent',hDlg,'Style','text','String','Sample rate (Hz):','HorizontalAlignment','left','Position',[10 figh-280 160 20]);
    hFs = uicontrol('Parent',hDlg,'Style','edit','String',num2str(params.fs),'Position',[180 figh-284 120 24]);

    % bytes per sample (for bin) - shown only if ext == '.bin' or user wants
    hLabB = uicontrol('Parent',hDlg,'Style','text','String','Bytes/sample (bin only):','HorizontalAlignment','left','Position',[10 figh-320 160 20],'Visible','off');
    hBps = uicontrol('Parent',hDlg,'Style','edit','String','','Position',[180 figh-324 120 24],'Visible','off');
    if strcmpi(ext,'.bin')
        set(hLabB,'Visible','on'); set(hBps,'Visible','on'); set(hBps,'String','2');
    end

    % OK / Cancel
    uicontrol('Parent',hDlg,'Style','pushbutton','String','OK','Position',[figw-200 10 80 28],'Callback',@okCb);
    uicontrol('Parent',hDlg,'Style','pushbutton','String','Cancel','Position',[figw-100 10 80 28],'Callback',@cancelCb);

    % dynamic visibility callback
    set(hNum,'Callback',@updateVis);
    set(hSign,'Callback',@updateVis);
    updateVis();

    uiwait(hDlg);
    if ~isvalid(hDlg)
        cancelled = true; return;
    end

    % collect results from controls
    try
        params.numericSel = hNum.String{get(hNum,'Value')};
        params.signSel = hSign.String{get(hSign,'Value')};
        params.Nbits = max(1, round(str2double(get(hN,'String'))));
        params.frac = max(0, round(str2double(get(hFrac,'String'))));
        params.vmin = str2double(get(hVmin,'String'));
        params.vmax = str2double(get(hVmax,'String'));
        params.peak = str2double(get(hPeak,'String'));
        params.fs = str2double(get(hFs,'String'));
        if isvalid(hBps)
            bpss = str2double(get(hBps,'String')); 
            if ~isnan(bpss), params.bps = bpss; end
        end
        if contains(params.numericSel,'Q')
            params.encodeType = 'Q';
        else
            if contains(params.signSel,'Unsigned')
                params.encodeType = 'Unsigned'; 
            else params.encodeType = 'Signed'; end
        end
    catch
        cancelled = true;
    end

    if ishandle(hDlg), close(hDlg); end
    return;

function updateVis(~,~)
    try
    ns = hNum.String{get(hNum,'Value')};
    ss = hSign.String{get(hSign,'Value')};
    if contains(ns,'Q')
        set(findobj(hDlg,'Tag','lab_frac'),'Visible','on'); set(findobj(hDlg,'Tag','edit_frac'),'Visible','on');
    else
        set(findobj(hDlg,'Tag','lab_frac'),'Visible','on'); set(findobj(hDlg,'Tag','edit_frac'),'Visible','on');
    end
    if contains(ss,'Unsigned')
        set(hVmin,'Visible','on'); set(hVmax,'Visible','on'); set(findobj(hDlg,'Tag','lab_vmin'),'Visible','on'); set(findobj(hDlg,'Tag','lab_vmax'),'Visible','on');
        set(hPeak,'Visible','off'); set(findobj(hDlg,'Tag','lab_peak'),'Visible','off');
    else
        set(hVmin,'Visible','off'); set(hVmax,'Visible','off'); set(findobj(hDlg,'Tag','lab_vmin'),'Visible','off'); set(findobj(hDlg,'Tag','lab_vmax'),'Visible','off');
        set(hPeak,'Visible','on'); set(findobj(hDlg,'Tag','lab_peak'),'Visible','on');
    end
    catch
    end
end

function okCb(~,~)
    uiresume(hDlg);
end

function cancelCb(~,~)
    cancelled = true; if ishandle(hDlg), close(hDlg); end
    end
end

% --- Helper for parameter access and syncing ---
function [encType, N, frac, numericSel, signSel] = getEncodingParams()
    % Read numeric/sign selections and N/frac from encode panel and
    % return a legacy-style encType string for compatibility:
    % encType = 'Q' | 'Unsigned' | 'Signed'
    % sensible defaults
    numericSel = 'Q format (N bits, frac)';
    signSel = 'Signed (Two''s complement)';
    N = 24; frac = 0;
    try
        if exist('hNumType','var') && ishandle(hNumType)
            numOpts = get(hNumType,'String'); numVal = get(hNumType,'Value');
            if iscell(numOpts) && numVal>=1 && numVal<=numel(numOpts)
                numericSel = numOpts{numVal};
            elseif ischar(numOpts)
                numericSel = numOpts;
            end
        end
    catch
        numericSel = 'Q format (N bits, frac)';
    end
    try
        if exist('hSignType','var') && ishandle(hSignType)
            signOpts = get(hSignType,'String'); signVal = get(hSignType,'Value');
            if iscell(signOpts) && signVal>=1 && signVal<=numel(signOpts)
                signSel = signOpts{signVal};
            elseif ischar(signOpts)
                signSel = signOpts;
            end
        end
    catch
        signSel = 'Signed (Two''s complement)';
    end
    % read N bits if available
    try
        if exist('hEncodePanel','var') && ishandle(hEncodePanel)
            hN = findobj(hEncodePanel,'Tag','enc_nbits');
            if ~isempty(hN) && ishandle(hN)
                Ntmp = str2double(get(hN,'String'));
                if ~isnan(Ntmp) && Ntmp>0, N = Ntmp; end
            end
            hFrac = findobj(hEncodePanel,'Tag','enc_frac');
            if ~isempty(hFrac) && ishandle(hFrac)
                % if popupmenu, get selected option; if edit/text, try parse
                sty = get(hFrac,'Style');
                if strcmp(sty,'popupmenu')
                    opts = get(hFrac,'String'); val = get(hFrac,'Value');
                    if iscell(opts) && val>=1 && val<=numel(opts)
                        fracTmp = str2double(opts{val});
                        if ~isnan(fracTmp), frac = fracTmp; end
                    end
                else
                    fracTmp = str2double(get(hFrac,'String'));
                    if ~isnan(fracTmp), frac = fracTmp; end
                end
            end
        end
    catch
        % leave defaults
    end
    % decide encType
    try
        if contains(numericSel,'Q')
            encType = 'Q';
        else
            if contains(signSel,'Unsigned')
                encType = 'Unsigned';
            else
                encType = 'Signed';
            end
        end
    catch
        encType = 'Q';
    end
end

function t = labelToTag(labelStr)
    t = lower(labelStr);
    t = regexprep(t,'[^a-z0-9]','_');
    t = regexprep(t,'_+','_');
end

function v = getParamValue(labelStr, default)
    tag = labelToTag(labelStr);
    h = findobj(hParamPanel,'Tag',tag);
    if isempty(h)
        v = default;
    else
        v = str2double(get(h,'String'));
        if isnan(v), v = default; end
    end
end

% avoid recursive updates
syncing = false;
function syncTimeSamples(src,~)
    if syncing, return; end
    syncing = true;
    try
        hDur = findobj(hParamPanel,'Tag','duration');
        % PRBS uses prbs_fs tag for sample rate; other modes use srate
        hS1 = findobj(hParamPanel,'Tag','srate');
        hS2 = findobj(hParamPanel,'Tag','prbs_fs');
        if ~isempty(hS1), hSRate = hS1; else hSRate = hS2; end

        if isempty(hDur) || isempty(hSRate)
            syncing = false; return;
        end
        % read current strings safely
        sdur = str2double(get(hDur,'String'));
        srate = str2double(get(hSRate,'String'));
        if isnan(sdur), sdur = 0; end
        if isnan(srate) || srate<=0, srate = 1; end

        % sanitize and write back normalized values
        set(hDur,'String',num2str(max(0,sdur)));
        set(hSRate,'String',num2str(max(1,srate)));
    catch
        % ignore errors
    end
    syncing = false;
end

% --- Interaction callbacks ---
function toggleZoom(src,~)
    try
        if get(src,'Value')
            zoom(hFig,'on');
            pan(hFig,'off'); set(btnPan,'Value',0);
            datacursormode(hFig,'off'); set(btnData,'Value',0);
        else
            zoom(hFig,'off');
        end
    catch
    end
end

function togglePan(src,~)
    try
        if get(src,'Value')
            pan(hFig,'on');
            zoom(hFig,'off'); set(btnZoom,'Value',0);
            datacursormode(hFig,'off'); set(btnData,'Value',0);
        else
            pan(hFig,'off');
        end
    catch
    end
end

function toggleDataCursor(src,~)
    try
        dcm = datacursormode(hFig);
        if get(src,'Value')
            set(dcm,'Enable','on');
            zoom(hFig,'off'); set(btnZoom,'Value',0);
            pan(hFig,'off'); set(btnPan,'Value',0);
        else
            set(dcm,'Enable','off');
        end
    catch
    end
end

function resetView(~,~)
    try
        % turn off interaction modes and reset button states
        zoom(hFig,'off'); set(btnZoom,'Value',0);
        pan(hFig,'off'); set(btnPan,'Value',0);
        dcm = datacursormode(hFig); set(dcm,'Enable','off'); set(btnData,'Value',0);
        % reset axes limits to auto
        axes(hAx); axis(hAx,'auto');
    catch
    end
end

function saveFigure(~,~)
    try
        [f,p] = uiputfile({'*.fig','MAT-file Figure (*.fig)';'*.png','PNG Image (*.png)';'*.pdf','PDF File (*.pdf)'},'Save Figure');
        if isequal(f,0), set(hStatus,'String','Save cancelled'); return; end
        full = fullfile(p,f);
        % if .fig saveas, else print
        [~,~,ext] = fileparts(full);
        switch lower(ext)
            case '.fig'
                savefig(hFig, full);
            case '.png'
                saveas(hFig, full);
            case '.pdf'
                saveas(hFig, full);
            otherwise
                saveas(hFig, full);
        end
        set(hStatus,'String',['Saved figure to ' full]);
    catch ME
        set(hStatus,'String',['Save error: ' ME.message]);
    end
end

function importCallback(~,~)
    filters = {'*.hex;*.mem;*.bin;*.coe;*.mif;*.csv','All supported files (*.hex,*.mem,*.bin,*.coe,*.mif,*.csv)';
               '*.hex','HEX (*.hex)';'*.mem','MEM (*.mem)';'*.bin','BIN (*.bin)';'*.coe','COE (*.coe)';'*.mif','MIF (*.mif)';'*.csv','CSV (*.csv)'};
    [fileName, filePath, filterIdx] = uigetfile(filters,'Import file');
    if isequal(fileName,0)
        set(hStatus,'String','Import cancelled');
        return;
    end
    fullpath = fullfile(filePath,fileName);
    [~,name,ext] = fileparts(fileName);
    ext = lower(ext);
    % Try to detect companion metadata JSON first (auto-fill and skip prompts)
    meta = [];
    metaCandidate1 = [fullpath '.meta.json'];
    metaCandidate2 = fullfile(filePath,[name '.meta.json']);
    metaCandidate3 = fullfile(filePath,[name '.json']);
    if exist(metaCandidate1,'file')
        try txt = fileread(metaCandidate1); meta = jsondecode(txt); end
    elseif exist(metaCandidate2,'file')
        try txt = fileread(metaCandidate2); meta = jsondecode(txt); end
    elseif exist(metaCandidate3,'file')
        try txt = fileread(metaCandidate3); meta = jsondecode(txt); end
    end

    % Ask or use metadata via a single unified dialog/function
    [params, cancelled] = askImportParams(meta, ext, 'file');
    if cancelled
        set(hStatus,'String','Import cancelled');
        return;
    end
    % unpack params
    numericSel = params.numericSel; signSel = params.signSel;
    encodeType = params.encodeType; Nbits = params.Nbits; frac = params.frac;
    vmin = params.vmin; vmax = params.vmax; peak = params.peak; fs = params.fs; bps = params.bps;
    if isfield(params,'meta')
        importedData.meta = params.meta;
    end
    % 文件读取
    switch ext
        case {'.hex','.mem'}
            txt = fileread(fullpath);
            lines = regexp(txt,'\r?\n','split');
            vals = [];
            for k=1:numel(lines)
                s = strtrim(lines{k});
                if isempty(s), continue; end
                try
                    s2 = regexprep(s,'^0x','');
                    v = hex2dec(s2);
                    vals(end+1) = v; %#ok<AGROW>
                catch
                end
            end
            intVals = uint64(vals);
        case '.coe'
            txt = fileread(fullpath);
            m = regexp(txt,'memory_initialization_vector\s*=\s*([^;]+);','tokens','ignorecase');
            if isempty(m), error('COE: cannot find initialization vector'); end
            vec = m{1}{1};
            parts = regexp(vec,',','split');
            vals = zeros(1,numel(parts));
            for k=1:numel(parts), vals(k)=hex2dec(strtrim(parts{k})); end
            intVals = uint64(vals);
        case '.mif'
            fid = fopen(fullpath,'r'); txt = textscan(fid,'%s','Delimiter','\n'); fclose(fid);
            lines = txt{1}; vals = [];
            inContent = false;
            for k=1:numel(lines)
                s = strtrim(lines{k}); if isempty(s), continue; end
                if startsWith(upper(s),'CONTENT BEGIN')
                    inContent = true; continue;
                end
                if ~inContent, continue; end
                if startsWith(upper(s),'END'), break; end
                parts = regexp(s,':','split');
                if numel(parts)>=2
                    dataPart = parts{2}; dataPart = regexprep(dataPart,';',''); dataPart = strtrim(dataPart);
                    try vals(end+1)=hex2dec(dataPart); catch; end
                end
            end
            intVals = uint64(vals);
        case '.csv'
            M = readmatrix(fullpath);
            intVals = uint64(M(:)');
        case '.bin'
            fid = fopen(fullpath,'r'); data = fread(fid,'uint8'); fclose(fid);
            n = numel(data);
            if mod(n,bps)~=0, warning('File size not a multiple of bytes per sample'); end
            nsamples = floor(n/bps);
            vals = zeros(1,nsamples,'uint64');
            for i=1:nsamples
                idx2 = (i-1)*bps + (1:bps);
                v = uint64(0);
                for j=1:bps
                    v = bitor(bitshift(v,8), uint64(data(idx2(j))));
                end
                vals(i)=v;
            end
            intVals = uint64(vals);
        otherwise
            error('Unsupported extension: %s',ext);
    end
    % Use a shared handler to set importedData and preview
    params2 = struct('numericSel',numericSel,'signSel',signSel,'encodeType',encodeType,'Nbits',Nbits,'frac',frac,'vmin',vmin,'vmax',vmax,'peak',peak,'fs',fs,'bps',bps);
    try
        handleImportedInts(uint64(intVals), fullpath, params2);
    catch ME
        set(hStatus,'String',['Import handling error: ' ME.message]);
    end
end

function exportCallback(~,~)
    % If imported data exists, ask whether to export it or generate new
    useImported = false;
    if ~isempty(importedData.intVals)
        choice = questdlg('Use imported data for export?','Export','Yes','No','Yes');
        if strcmp(choice,'Yes')
            useImported = true;
        end
    end
    if useImported
        intVals = importedData.intVals;
        % try to infer Nbits if missing
        if isempty(importedData.Nbits)
            maxv = max(double(intVals));
            if maxv<=0
                N = 16;
            else
                N = max(1, ceil(log2(double(maxv)+1)));
            end
        else
            N = importedData.Nbits;
        end
        % prepare fullpath via uiputfile
        filters = {'*.hex;*.mem;*.bin;*.coe;*.mif;*.csv','All supported files (*.hex,*.mem,*.bin,*.coe,*.mif,*.csv)';
                   '*.hex','HEX (*.hex)';'*.mem','MEM (*.mem)';'*.bin','BIN (*.bin)';'*.coe','COE (*.coe)';'*.mif','MIF (*.mif)';'*.csv','CSV (*.csv)'};
        [fileName, filePath, filterIdx] = uiputfile(filters,'Save imported data as');
        if isequal(fileName,0)
            set(hStatus,'String','Export cancelled'); return;
        end
        fullpath = fullfile(filePath,fileName);
        [~,~,ext] = fileparts(fileName); ext = lower(ext);
        if isempty(ext)
            ext = '.hex';
        end
        try
            writeOutputFile(fullpath, intVals, N, ext);
            set(hStatus,'String',['Exported imported data to ' fullpath]);
        catch ME
            set(hStatus,'String',['Write error: ' ME.message]);
        end
        return;
    end
    % Get encoding params from UI (use two popups and fields)
    try
        [encType, N, frac] = getEncodingParams();
    catch
        set(hStatus,'String','Error reading encoding params'); return;
    end

    % 先生成信号
    try
        [y, t, info] = generateSignalFromUI();
    catch ME
        set(hStatus,'String',['Error generating signal: ' ME.message]);
        return;
    end
    % Convert to integers according to encoding
    try
        intVals = encodeSignalToIntegers(y, encType, N, frac);
    catch ME
        set(hStatus,'String',['Encoding error: ' ME.message]); return;
    end
    % (signal already generated above)
    % Choose filename (support more formats)
    filters = {'*.hex;*.mem;*.bin;*.coe;*.mif;*.csv','All supported files (*.hex,*.mem,*.bin,*.coe,*.mif,*.csv)';
               '*.hex','HEX (*.hex)';'*.mem','MEM (*.mem)';'*.bin','BIN (*.bin)';'*.coe','COE (*.coe)';'*.mif','MIF (*.mif)';'*.csv','CSV (*.csv)'};
    [fileName, filePath, filterIdx] = uiputfile(filters,'Save as');
    if isequal(fileName,0)
        set(hStatus,'String','Export cancelled'); return;
    end
    fullpath = fullfile(filePath,fileName);
    % Determine export format from extension (or selected filter)
    [~,~,ext] = fileparts(fileName);
    ext = lower(ext);
    if isempty(ext) && ~isempty(filterIdx)
        % map filter index to extension when user picks a filter but omits extension
        extlist = {'.hex','.hex','.mem','.bin','.coe','.mif','.csv'}; % first map is for combined filter
        if filterIdx>=1 && filterIdx<=numel(extlist)
            ext = extlist{filterIdx};
        else
            ext = '.hex';
        end
    end
    try
        writeOutputFile(fullpath, intVals, N, ext);
        set(hStatus,'String',['Exported to ' fullpath]);
    catch ME
        set(hStatus,'String',['Write error: ' ME.message]);
    end
end

function importFromWorkspaceCallback(~,~)
    % Let user pick a variable from the base workspace and import it
    vars = evalin('base','whos');
    names = {vars.name};
    if isempty(names)
        set(hStatus,'String','Workspace empty: no variable to import');
        return;
    end
    [sel, ok] = listdlg('PromptString','Select a workspace variable to import:','SelectionMode','single','ListString',names,'Name','Import from Workspace');
    if ~ok || isempty(sel)
        set(hStatus,'String','Import from workspace cancelled'); return;
    end
    vname = names{sel};
    try
        data = evalin('base', vname);
    catch ME
        set(hStatus,'String',['Failed to read variable: ' ME.message]); return;
    end
    if ~isnumeric(data)
        set(hStatus,'String','Selected variable is not numeric'); return;
    end
    % If integer-like, treat as encoded integers; otherwise treat as float waveform
    if isinteger(data) || all(mod(data(:),1)==0)
        % reuse shared handler for workspace-imported integers
        intValsW = uint64(data(:)');
        [params, cancelled] = askImportParams([], '', 'workspace');
        if cancelled
            set(hStatus,'String','Import cancelled');
            return;
        end
        params2 = struct('numericSel',params.numericSel,'signSel',params.signSel,'encodeType',params.encodeType,'Nbits',params.Nbits,'frac',params.frac,'vmin',params.vmin,'vmax',params.vmax,'peak',params.peak,'fs',params.fs,'bps',params.bps,'meta',[]);
        try
            handleImportedInts(intValsW, ['workspace:' vname], params2);
        catch ME
            set(hStatus,'String',['Import handling error: ' ME.message]);
        end
    else
        y = double(data(:)');
        importedData.floatY = y;
        importedData.intVals = [];
        importedData.fileName = ['workspace:' vname];
        cla(hAx);
        plot(hAx, y);
        title(hAx,['Imported (float): workspace:' vname]);
        set(hStatus,'String',['Imported float variable ''' vname ''' from workspace (' num2str(numel(y)) ' samples)']);
    end
end

function exportToWorkspaceCallback(~,~)
    % Export either imported integer data (if present) or generated/encoded signal to base workspace
    prompt = {'Variable name in base workspace:'};
    def = {'exported_signal'};
    answ = inputdlg(prompt,'Export to Workspace',[1 50],def);
    if isempty(answ), set(hStatus,'String','Export to workspace cancelled'); return; end
    vname = answ{1};
    try
        if ~isempty(importedData.intVals)
            assignin('base', vname, importedData.intVals);
            set(hStatus,'String',['Exported imported integer data to workspace variable ''' vname '''']);
        elseif isfield(importedData,'floatY') && ~isempty(importedData.floatY)
            assignin('base', vname, importedData.floatY);
            set(hStatus,'String',['Exported imported float data to workspace variable ''' vname '''']);
        else
            % generate signal and encode according to current UI settings
            [y, ~, ~] = generateSignalFromUI();
            % determine encoding params (use helper)
            try
                [encType, N, frac] = getEncodingParams();
            catch
                set(hStatus,'String','Error reading encoding params'); return;
            end
            intVals = encodeSignalToIntegers(y, encType, N, frac);
            assignin('base', vname, intVals);
            set(hStatus,'String',['Exported generated signal (encoded) to workspace variable ''' vname '''']);
        end
    catch ME
        set(hStatus,'String',['Export to workspace failed: ' ME.message]);
    end
end

function [y, t, info] = generateSignalFromUI()
    type = hSignal.String{hSignal.Value};
    pc = get(hParamPanel,'Children');
    edits = findobj(pc,'Style','edit');
    % Order of edits depends on signal type created earlier
    typeLower = lower(type);
    switch typeLower
        case 'sine'
            A = getParamValue('Amplitude',1);
            f = getParamValue('Frequency (Hz)',50);
            ph = getParamValue('Phase (deg)',0);
            % sample rate may be tagged as 'srate' or 'prbs_fs'
            hfs = findobj(hParamPanel,'Tag','srate'); if isempty(hfs), hfs = findobj(hParamPanel,'Tag','prbs_fs'); end
            if isempty(hfs), fs = 48000; else fs = str2double(get(hfs,'String')); end
            duration = getParamValue('Duration (s)',10);
            Ns = max(1, round(duration * fs));
            t = (0:Ns-1)/fs;
            y = A * sin(2*pi*f*t + deg2rad(ph));
            % apply offset if provided
            off = getParamValue('Offset',0);
            y = y + off;
            info.type = 'Sine';
        case 'square'
            A = getParamValue('Amplitude',1);
            f = getParamValue('Frequency (Hz)',50);
            duty = getParamValue('Duty (%)',50);
            hfs = findobj(hParamPanel,'Tag','srate'); if isempty(hfs), hfs = findobj(hParamPanel,'Tag','prbs_fs'); end
            if isempty(hfs), fs = 48000; else fs = str2double(get(hfs,'String')); end
            duration = getParamValue('Duration (s)',10);
            Ns = max(1, round(duration * fs));
            t = (0:Ns-1)/fs;
            y = A * sign(sin(2*pi*f*t));
            if duty~=50
                threshold = cos(pi*(duty/100));
                y = A * (sin(2*pi*f*t)>threshold) * 1 + A * (sin(2*pi*f*t)<=threshold) * -1;
            end
            % apply offset
            off = getParamValue('Offset',0);
            y = y + off;
            info.type = 'Square';
        case 'white noise'
            % Band-limited white noise: Amplitude, Duration, SampleRate, Low/High cutoff, FIR order
            A = getParamValue('Amplitude', 1);
            % sample rate may be tagged as 'srate' or 'prbs_fs'
            hfs = findobj(hParamPanel,'Tag','srate'); if isempty(hfs), fs = 48000; else fs = str2double(get(hfs,'String')); end
            duration = getParamValue('Duration (s)',10);
            Ns = max(1, round(duration * fs));
            t = (0:Ns-1)/fs;
            % generate white Gaussian noise
            x = A * randn(1, Ns);
            % read band edges and filter order (use labels so getParamValue can find them)
            lowf = getParamValue('Low Cutoff (Hz)', 0);
            highf = getParamValue('High Cutoff (Hz)', min(fs/2*0.99, fs/2));
            m = max(0, round(getParamValue('FIR order (even)', 128)));
            if mod(m,2)==1, m = m+1; end

            % sanitize frequencies
            lowf = max(0, lowf);
            highf = min(fs/2-1e-6, highf);
            % design filter based on low/high values
            y = x;
            try
                if highf <= 0 || highf <= lowf
                    % invalid band -> no filtering
                    y = x;
                else
                    if lowf <= 0
                        % lowpass with cutoff highf
                        Wn = highf / (fs/2);
                        if Wn <= 0 || Wn >= 1
                            y = x;
                        else
                            b = fir1(m, Wn);
                            y = filter(b, 1, x);
                        end
                    elseif highf >= fs/2 - 1e-9
                        % highpass with cutoff lowf
                        Wn = lowf / (fs/2);
                        if Wn <= 0 || Wn >= 1
                            y = x;
                        else
                            b = fir1(m, Wn, 'high');
                            y = filter(b, 1, x);
                        end
                    else
                        % bandpass
                        Wn = [lowf highf] / (fs/2);
                        if Wn(1) <= 0 || Wn(2) >= 1 || Wn(2) <= Wn(1)
                            y = x;
                        else
                            b = fir1(m, Wn);
                            y = filter(b, 1, x);
                        end
                    end
                end
            catch
                % on any failure, fall back to raw noise
                y = x;
            end
            info.type = 'White Noise';
        case 'prbs'
            try
                hAmp = findobj(hParamPanel,'Tag','prbs_amp');
                A = str2double(get(hAmp,'String'));
            catch
                A = 1;
            end
            try
                hord = findobj(hParamPanel,'Tag','prbs_order'); ord = str2double(get(hord,'String'));
            catch
                ord = 13;
            end
            try
                hseed = findobj(hParamPanel,'Tag','prbs_seed'); seed = str2double(get(hseed,'String'));
            catch
                seed = 23533;
            end
            try
                hDuration = findobj(hParamPanel,'Tag','duration'); duration = str2double(get(hDuration,'String'));
            catch
                duration = 10;
            end
            try
                hfs = findobj(hParamPanel,'Tag','prbs_fs'); fs = str2double(get(hfs,'String'));
            catch
                fs = 48000;
            end
            try
                htaps = findobj(hParamPanel,'Tag','prbs_taps'); tapsStr = get(htaps,'String');
                taps = eval(tapsStr);
            catch
                taps = [];
            end
            if isempty(taps)
                taps = ord:-1:ord-2; % fallback taps
            end
            Ns = round(duration * fs);
            t = (0:Ns-1)/fs;
            bits = lfsr_prbs(ord, seed, Ns, taps);
            y = A * (2*bits-1);
            % apply offset
            off = getParamValue('Offset',0);
            y = y + off;
            info.type = 'PRBS';
        otherwise
            error('Unknown signal type');
    end
end

function out = lfsr_prbs(order, seed, Nout, taps)
    % Robust Fibonacci-style LFSR (MSB-first) producing 0/1 sequence of length Nout
    % taps should be specified as polynomial degrees, e.g. [13 11] for x^13 + x^11 + 1
    if nargin<4, taps = []; end
    if seed == 0
        seed = 1; % avoid all-zero state
    end
    % sanitize taps: keep integers within [1,order]
    taps = unique(floor(taps));
    taps = taps(taps>=1 & taps<=order);
    if isempty(taps)
        % default primitive-ish taps for small orders (fallback)
        taps = max(1, order-1);
    end

    % Initialize state as MSB-first vector: state(1)=bit for x^order, state(order)=LSB
    state = zeros(1, order);
    for i = 1:order
        % bitget with position i extracts bit at weight 2^(i-1) (LSB=1)
        % we want state(1)=MSB -> bit position = order - 1 + 1 = order
        state(i) = bitget(uint32(seed), order - i + 1);
    end
    % ensure not all zeros
    if all(state==0)
        state(end) = 1;
    end

    out = zeros(1, Nout);
    % map polynomial degrees to state indices (MSB-first)
    taps_idx = order - taps + 1; % degree t -> index in state
    taps_idx = taps_idx(taps_idx>=1 & taps_idx<=order);

    for k = 1:Nout
        % output bit: take LSB (degree 1) OR take MSB depending on convention
        % We'll output the LSB (state(end)) to get typical PRBS ordering used elsewhere
        out(k) = state(end);

        % compute feedback as XOR of the tapped bits (using the provided degrees)
        fb = 0;
        for tt = taps_idx
            fb = bitxor(fb, state(tt));
        end

        % shift right by one position, insert feedback at MSB (state(1))
        state = [fb, state(1:end-1)];
    end
end

function intVals = encodeSignalToIntegers(y, encType, Nbits, frac)
    % Normalize signal to [-1,1] unless Q-format where absolute scaling kept
    if contains(encType,'Q')
        % Q format: scale by 2^frac
        scale = 2^frac;
        raw = round(y * scale);
        maxPos = 2^(Nbits-1)-1;
        minNeg = -2^(Nbits-1);
        raw(raw>maxPos) = maxPos;
        raw(raw<minNeg) = minNeg;
        % Convert to two's complement representation (unsigned integer) for bit pattern
        intVals = mod(raw, 2^Nbits);
    elseif startsWith(encType,'Unsigned')
        % map y normalized to [-1,1] -> [0, 2^N-1]
        if max(abs(y))==0
            yN = zeros(size(y));
        else
            yN = y / max(abs(y));
        end
        scaled = round( (yN + 1)/2 * (2^Nbits-1) );
        scaled(scaled<0)=0; scaled(scaled>2^Nbits-1)=2^Nbits-1;
        intVals = uint64(scaled);
    else % Signed two's complement
        if max(abs(y))==0
            yN = zeros(size(y));
        else
            yN = y / max(abs(y));
        end
        maxPos = 2^(Nbits-1)-1;
        scaled = round( yN * maxPos );
        scaled(scaled>maxPos)=maxPos; scaled(scaled<-2^(Nbits-1))=-2^(Nbits-1);
        % convert negative numbers to two's complement unsigned representation
        intVals = mod(scaled, 2^Nbits);
    end
end

function writeOutputFile(fullpath, intVals, Nbits, fmt)
    % Write according to fmt
    % normalize format string: accept '.hex' or 'hex'
    if startsWith(fmt,'.')
        fmt = fmt(2:end);
    end
    fmt = lower(fmt);
    switch fmt
        case {'hex','mem'}
            % text file, one hex word per line, zero padded to Nbits/4 digits
            fid = fopen(fullpath,'w');
            if fid<0, error('Cannot open file for writing'); end
            nHex = ceil(Nbits/4);
            for k=1:numel(intVals)
                fprintf(fid, ['%0' num2str(nHex) 'X\n'], intVals(k));
            end
            fclose(fid);
        case 'bin'
            % raw binary. Pack each sample into ceil(Nbits/8) bytes, big-endian
            nBytes = ceil(Nbits/8);
            fid = fopen(fullpath,'w');
            if fid<0, error('Cannot open file for writing'); end
            for k=1:numel(intVals)
                val = uint64(intVals(k));
                bytes = zeros(1,nBytes,'uint8');
                for b = 1:nBytes
                    shift = 8*(nBytes-b);
                    bytes(b) = bitand(bitshift(val, -shift), 255);
                end
                fwrite(fid, bytes, 'uint8');
            end
            fclose(fid);
        case 'coe'
            % Xilinx COE file: memory_initialization_radix=16; memory_initialization_vector=..;
            fid = fopen(fullpath,'w');
            if fid<0, error('Cannot open file for writing'); end
            nHex = ceil(Nbits/4);
            fprintf(fid,'memory_initialization_radix=16;\n');
            fprintf(fid,'memory_initialization_vector=');
            for k=1:numel(intVals)
                fprintf(fid,['%0' num2str(nHex) 'X'], intVals(k));
                if k<numel(intVals)
                    fprintf(fid,',');
                else
                    fprintf(fid,';\n');
                end
            end
            fclose(fid);
        case 'mif'
            % Altera/Intel MIF basic writer
            fid = fopen(fullpath,'w');
            if fid<0, error('Cannot open file for writing'); end
            depth = numel(intVals);
            fprintf(fid,'WIDTH=%d;\n',Nbits);
            fprintf(fid,'DEPTH=%d;\n',depth);
            fprintf(fid,'ADDRESS_RADIX=UNS;\n');
            fprintf(fid,'DATA_RADIX=HEX;\n\n');
            fprintf(fid,'CONTENT BEGIN\n');
            for k=1:depth
                fprintf(fid,'%d : %s;\n',k-1,upper(dec2hex(intVals(k),ceil(Nbits/4))));
            end
            fprintf(fid,'END;\n');
            fclose(fid);
        case 'csv'
            % CSV: decimal values, one per line
            fid = fopen(fullpath,'w');
            if fid<0, error('Cannot open file for writing'); end
            for k=1:numel(intVals)
                fprintf(fid,'%d\n',intVals(k));
            end
            fclose(fid);
        otherwise
            error('Unknown format: %s', fmt);
    end
end

function handleImportedInts(intVals, sourceName, params)
    % Centralized handler to store imported ints and preview restored waveform.
    if nargin<3, params = struct(); end
    if isempty(intVals) || numel(intVals)==0
        set(hStatus,'String','Imported data empty');
        return;
    end
    try
        importedData.intVals = uint64(intVals(:)');
        importedData.fileName = sourceName;
        if isfield(params,'Nbits'), importedData.Nbits = params.Nbits; else importedData.Nbits = 24; end
        if isfield(params,'frac'), importedData.frac = params.frac; else importedData.frac = 0; end
        if isfield(params,'encodeType'), importedData.encodeType = params.encodeType; else importedData.encodeType = 'Signed'; end
        if isfield(params,'fs'), importedData.fs = params.fs; else importedData.fs = 48000; end
        if isfield(params,'vmin'), importedData.vmin = params.vmin; else importedData.vmin = []; end
        if isfield(params,'vmax'), importedData.vmax = params.vmax; else importedData.vmax = []; end
        if isfield(params,'peak'), importedData.peak = params.peak; else importedData.peak = []; end
        if isfield(params,'meta'), importedData.meta = params.meta; end
    catch ME
        error('Failed to store imported data: %s', ME.message);
    end

    set(hStatus,'String',['Imported ' num2str(numel(importedData.intVals)) ' samples from ' sourceName]);
    cla(hAx);
    % Reconstruct float waveform for preview according to encoding
    yRestored = double(importedData.intVals);
    try
        switch importedData.encodeType
            case 'Q'
                maxPos = 2^(importedData.Nbits-1)-1;
                yRestored(yRestored > maxPos) = yRestored(yRestored > maxPos) - 2^importedData.Nbits;
                yRestored = yRestored / (2^importedData.frac);
            case 'Unsigned'
                if isempty(importedData.vmin) || isempty(importedData.vmax) || isnan(importedData.vmin) || isnan(importedData.vmax)
                    yRestored = (double(importedData.intVals) / (2^importedData.Nbits-1)) * 2 - 1;
                else
                    yRestored = (double(importedData.intVals) / (2^importedData.Nbits-1)) * (importedData.vmax - importedData.vmin) + importedData.vmin;
                end
            otherwise % Signed
                maxPos = 2^(importedData.Nbits-1)-1;
                yRestored(yRestored > maxPos) = yRestored(yRestored > maxPos) - 2^importedData.Nbits;
                if isempty(importedData.peak) || isnan(importedData.peak) || importedData.peak==0
                    yRestored = yRestored / maxPos;
                else
                    yRestored = (yRestored / maxPos) * importedData.peak;
                end
        end
        if numel(unique(yRestored))<=2
            stairs(hAx, yRestored);
        else
            plot(hAx, yRestored);
        end
    catch
        % fallback: plot raw integer values
        if numel(unique(importedData.intVals))<=2
            stairs(hAx,double(importedData.intVals));
        else
            plot(hAx,double(importedData.intVals));
        end
    end
    title(hAx,['Imported: ' sourceName]);
end
% Close main function
end