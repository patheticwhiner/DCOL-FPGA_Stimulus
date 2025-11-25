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
addpath('utils');
% Create main figure
hFig = figure('Name','Signal Generator','NumberTitle','off', 'MenuBar','none', ...
    'ToolBar','none','Position',[300 200 1200 800]);

% Set default UI font sizes for controls/panels created under this figure
set(hFig, 'DefaultUicontrolFontSize', 10, 'DefaultUipanelFontSize', 10);

% Create tab group: first tab shows About/README text, second tab holds the generator UI
hTabGroup = uitabgroup('Parent',hFig,'Units','normalized','Position',[0 0 1 1]);
hTab1 = uitab('Parent',hTabGroup,'Title','About');
hTab2 = uitab('Parent',hTabGroup,'Title','Generator');
% Third tab: embed the FX-LMS GUI here by calling fxlms_gui with the tab as parent
hTab3 = uitab('Parent',hTabGroup,'Title','FXLMS');
try
    % attempt to build the fxlms GUI inside the tab
    fxlms_gui(hTab3);
catch
    % if embedding fails (older fxlms_gui version), provide a fallback button to open it in a separate window
    uicontrol('Parent',hTab3,'Style','text','Units','normalized','Position',[0.05 0.9 0.9 0.05],'String','Embedded FX-LMS not available. Click below to open standalone GUI.','HorizontalAlignment','left');
    uicontrol('Parent',hTab3,'Style','pushbutton','Units','normalized','Position',[0.4 0.45 0.2 0.08],'String','Open FX-LMS GUI','Callback',@(s,e) fxlms_gui());
end

% Try to show an image (assets/gitlogo.png) on the About tab if present
try
    imgPath = fullfile(fileparts(mfilename('fullpath')),'assets','gitlogo.png');
    if exist(imgPath,'file')
        % create a small axes on the right side of the About tab and display the image
        axImg = axes('Parent',hTab1,'Units','normalized','Position',[0.02 0.4 0.96 0.55]);
        try
            im = imread(imgPath);
            % use imshow if available, otherwise fall back to image()
            if exist('imshow','file')==2
                imshow(im,'Parent',axImg);
            else
                image(axImg,im);
                axis(axImg,'image');
            end
            axis(axImg,'off');
        catch
            % ignore image display errors
            if ishandle(axImg), delete(axImg); end
        end
    end
catch
    % ignore any issues locating or drawing the image
end

% Place a read-only multi-line edit on the About tab with a short README excerpt
readmeText = [ ...
    "Signal Generator GUI for MATLAB\r\n\r\n", ...
    "This GUI generates common test signals (Sine, Square, PRBS, White Noise),\r\n", ...
    "allows preview and fixed-point quantization, and exports samples to\r\n", ...
    "FPGA/embedded-friendly formats (.hex, .mem, .bin, .csv).\r\n\r\n", ...
    "Usage: run `signal_generator_gui` in MATLAB, choose a signal type, set\r\n", ...
    "parameters and encoding, then Generate & Preview and Export as needed.\r\n\r\n", ...
    "Import: supports .hex/.mem/.bin/.csv and workspace variables. Companion\r\n", ...
    "meta JSON (e.g. file.meta.json) is auto-detected when present.\r\n\r\n", ...
    "See README_GUI_ForMat.md in the project for full details." ];
% place text on left portion of About tab leaving room for an image on the right
uicontrol('Parent',hTab1,'Style','edit','String',readmeText,'Units','normalized',...
    'Position',[0.12 0.12 0.80 0.2],'Max',2,'Min',0,'Enable','inactive','HorizontalAlignment','left','FontSize',10);


% Layout: top controls, left parameters panel, right encoding panel, big axes below
% Top: Signal & Fixed-format selectors
uicontrol('Parent',hTab2,'Style','text','String','Signal:','Units','normalized',...
    'Position',[0.02 0.94 0.12 0.04],'HorizontalAlignment','left','FontSize',10);
hSignal = uicontrol('Parent',hTab2,'Style','popupmenu','String',{'Sine','Square','White Noise','PRBS'}, ...
    'Units','normalized','Position',[0.14 0.94 0.28 0.04],'Callback',@signalChanged,'FontSize',10);

uicontrol('Parent',hTab2,'Style','text','String','Sign:','Units','normalized',...
    'Position',[0.46 0.94 0.04 0.04],'HorizontalAlignment','left','FontSize',10);
hSignType = uicontrol('Parent',hTab2,'Style','popupmenu', ...
    'String',{'Unsigned','Signed (Two''s complement)'},...
    'Units','normalized','Position',[0.50 0.94 0.18 0.04],'Callback',@encodeChanged,'FontSize',10,'Value',2);
uicontrol('Parent',hTab2,'Style','text','String','Numeric format:','Units','normalized',...
    'Position',[0.70 0.94 0.10 0.04],'HorizontalAlignment','left','FontSize',10);
hNumType = uicontrol('Parent',hTab2,'Style','popupmenu', ...
    'String',{'Integer (N bits)','Q format (N bits, frac)'},...
    'Units','normalized','Position',[0.80 0.94 0.18 0.04],'Callback',@encodeChanged,'FontSize',10,'Value',2);

% Left parameters panel (large)
hParamPanel = uipanel('Parent',hTab2,'Title','Parameters','Units','normalized',...
    'Position',[0.02 0.55 0.46 0.37],'FontSize',10);

% Right encoding panel to show encoding params nicely 
hEncodePanel = uipanel('Parent',hTab2,'Title','Encoding Params','Units','normalized',...
    'Position',[0.50 0.62 0.48 0.3],'FontSize',10);

% Interaction controls (Zoom / Pan / Data Cursor / Reset / Save)
btnZoom = uicontrol('Parent',hTab2,'Style','togglebutton','String','Zoom','Units','normalized',...
    'Position',[0.50 0.565 0.055 0.035],'Callback',@toggleZoom,'FontSize',10);
btnPan = uicontrol('Parent',hTab2,'Style','togglebutton','String','Pan','Units','normalized',...
    'Position',[0.56 0.565 0.055 0.035],'Callback',@togglePan,'FontSize',10);
btnData = uicontrol('Parent',hTab2,'Style','togglebutton','String','Data Cursor','Units','normalized',...
    'Position',[0.62 0.565 0.085 0.035],'Callback',@toggleDataCursor,'FontSize',10);
uicontrol('Parent',hTab2,'Style','pushbutton','String','Reset View','Units','normalized',...
    'Position',[0.71 0.565 0.07 0.035],'Callback',@resetView,'FontSize',9);
uicontrol('Parent',hTab2,'Style','pushbutton','String','Save Fig','Units','normalized',...
    'Position',[0.79 0.565 0.09 0.035],'Callback',@saveFigure,'FontSize',9);

% (Export Format moved to bottom next to action buttons)

% Big axes below
hAx = axes('Parent',hTab2,'Units','normalized','Position',[0.05 0.14 0.90 0.36]);
% tag the main axes so callbacks outside nested scope can find it if needed
set(hAx,'Tag','main_axes');
title(hAx,'Preview');
xlabel(hAx,'Time (s)');
ylabel(hAx,'Amplitude');

% hStatus = uicontrol('Parent',hFig,'Style','text','String','Ready','Units','normalized',...
%     'Position',[0.05 0.10 0.90 0.03],'HorizontalAlignment','left');
% Status bar
hStatus = uicontrol('Parent',hTab2,'Style','text','String','Ready','Units','normalized',...
    'Position',[0.04 0.07 0.96 0.02],'HorizontalAlignment','left','FontSize',10);

% Bottom action buttons - reflowed with uniform margins and gaps
% Layout parameters: left/right margin = 0.04, button width = 0.12, gap = 0.04
btn_w = 0.12; btn_gap = 0.04; left_margin = 0.04; y_pos = 0.02; btn_h = 0.04;
uicontrol('Parent',hTab2,'Style','togglebutton','String','Quantize','Units','normalized',...
    'Position',[left_margin, y_pos, btn_w, btn_h],'Tag','btn_quantize','FontSize',10,'Value',0, 'TooltipString','Toggle to overlay quantized waveform on preview','Callback',@toggleQuantize);
uicontrol('Parent',hTab2,'Style','pushbutton','String','Generate & Preview','Units','normalized',...
    'Position',[left_margin + (btn_w+btn_gap)*1, y_pos, btn_w, btn_h],'Callback',@generatePreview,'FontSize',10);
% Import button (between Generate and Export)
uicontrol('Parent',hTab2,'Style','pushbutton','String','Import...','Units','normalized',...
    'Position',[left_margin + (btn_w+btn_gap)*2, y_pos, btn_w, btn_h],'Callback',@importCallback,'FontSize',10);
uicontrol('Parent',hTab2,'Style','pushbutton','String','Export...','Units','normalized',...
    'Position',[left_margin + (btn_w+btn_gap)*3, y_pos, btn_w, btn_h],'Callback',@exportCallback,'FontSize',10);
uicontrol('Parent',hTab2,'Style','pushbutton','String','Import from Workspace','Units','normalized',...
    'Position',[left_margin + (btn_w+btn_gap)*4, y_pos, btn_w, btn_h],'Callback',@importFromWorkspaceCallback,'FontSize',10);
uicontrol('Parent',hTab2,'Style','pushbutton','String','Export to Workspace','Units','normalized',...
    'Position',[left_margin + (btn_w+btn_gap)*5, y_pos, btn_w, btn_h],'Callback',@exportToWorkspaceCallback,'FontSize',10);

% Initialize default parameter controls
currentParams = struct();
createParamControls('Sine');
createEncodeControls();

% storage for imported data (canonical unified structure used by generate/import)
importedData = struct();
importedData.floatY = [];
importedData.t = [];
importedData.info = [];
importedData.intVals = [];
importedData.fileName = '';
importedData.Nbits = [];
importedData.fs = [];
importedData.frac = [];
importedData.encodeType = '';
importedData.meta = [];
importedData.lastEncode = [];

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
            % Ensure quantized overlay respects toggle state even if doQuant is false
            % (i.e., remove existing overlay when toggle is off)
            try
                hBtnCheck = findobj(hFig,'Tag','btn_quantize');
                if isempty(hBtnCheck) || ~get(hBtnCheck,'Value')
                    oldQ2 = findobj(hAx,'Tag','quant_preview'); delete(oldQ2);
                end
            catch
            end
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
            'Position',[0.03 0.36 0.38 0.16],'HorizontalAlignment','left','FontSize',10);
        uicontrol('Parent',hEncodePanel,'Style','text','String',' ','Units','normalized',...
            'Position',[0.52 0.36 0.16 0.16],'HorizontalAlignment','left','FontSize',10,'Tag','enc_frac');
        if contains(signSel,'Unsigned')
            mapStr = 'Mapping: signal normalized to [-1,1] then to unsigned [0,2^N-1]';
        else
            mapStr = 'Mapping: signal normalized to [-1,1] then to signed two''s complement';
        end
    end
    uicontrol('Parent',hEncodePanel,'Style','text','String',mapStr,'Units','normalized',...
        'Position',[0.03 0.02 0.92 0.12],'HorizontalAlignment','left','FontSize',10);
    % Note: Quantize toggle moved to bottom action buttons for consistent placement
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
        [y_full, t_full, info] = generateSignalFromUI();
        % Performance safeguard: only truncate for plotting; keep full arrays for export/encoding
        Ns_orig = numel(y_full);
        MAX_PREVIEW_POINTS = 5000; % configurable default
        if Ns_orig > MAX_PREVIEW_POINTS
            y_plot = y_full(1:MAX_PREVIEW_POINTS);
            t_plot = t_full(1:MAX_PREVIEW_POINTS);
            truncated = true;
        else
            y_plot = y_full; t_plot = t_full; truncated = false;
        end
        cla(hAx);
        % plot original preview (use truncated arrays for performance) and tag it so toggleQuantize can find it
        if isfield(info,'type') && strcmpi(info.type,'PRBS')
            hOrig = stairs(hAx, t_plot, y_plot, '-b');
        else
            hOrig = plot(hAx, t_plot, y_plot, '-b');
        end
        try set(hOrig,'Tag','orig_preview'); catch; end
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
            hBtn = findobj(hFig,'Tag','btn_quantize');
            doQuant = ~isempty(hBtn) && ishandle(hBtn) && get(hBtn,'Value');
        catch
            doQuant = false;
        end
        if doQuant
            try
                % read encoding params from the two-popups and fields
                [encType, N, frac] = getEncodingParams();
                % encode and reconstruct quantized waveform using full arrays, then truncate for plotting
                intQ_full = encodeSignalToIntegers(y_full, encType, N, frac);
                yq_full = reconstructFromInts(y_full, double(intQ_full), encType, N, frac);
                yq_plot = yq_full(1:numel(y_plot));
                hold(hAx,'on');
                % remove any existing quantized overlay then draw new one (tagged)
                oldQ = findobj(hAx,'Tag','quant_preview'); delete(oldQ);
                if isfield(info,'type') && strcmpi(info.type,'PRBS')
                    hQ = stairs(hAx, t_plot, yq_plot, '--r','LineWidth',1.0); %#ok<NASGU>
                else
                    hQ = plot(hAx, t_plot, yq_plot, '--r','LineWidth',1.0); %#ok<NASGU>
                end
                try set(hQ,'Tag','quant_preview'); catch; end
                legend(hAx,{'Original','Quantized'},'Location','best');
                hold(hAx,'off');
            catch
                % don't let overlay errors break preview
            end
        end
        % Save full generated waveform into shared importedData so import/generate share state
        try
            importedData.floatY = y_full;
            importedData.t = t_full;
            % infer and store sample rate when possible
            if numel(t_full)>1
                importedData.fs = 1/(t_full(2)-t_full(1));
            else
                importedData.fs = [];
            end
            importedData.info = info;
            importedData.intVals = [];
            importedData.fileName = 'generated';
            importedData.Nbits = [];
            % record last-used encoding UI settings optionally
            try
                [etmp, Ntmp, frtmp] = getEncodingParams();
                importedData.lastEncode = struct('encodeType',etmp,'N',Ntmp,'frac',frtmp);
            catch
            end
        catch
        end
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
    params = struct('importType','Quantized','numericSel','Integer (N bits)','signSel','Signed (Two''s complement)','encodeType','Signed',...
        'Nbits',24,'frac',0,'vmin',[],'vmax',[],'peak',[],'fs',48000,'bps',[],'meta',[]);
    try
        if ~isempty(meta)
            % populate from metadata and return
            params.meta = meta;
            % if metadata carries numeric-type info, prefer Quantized, else Raw
            if isfield(meta,'numericType') || isfield(meta,'numeric_type') || isfield(meta,'Nbits')
                params.importType = 'Quantized';
            else
                params.importType = 'Raw';
            end
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
    figw = 420; figh = 420; fx = dpos(1)+dpos(3)/2-figw/2; fy = dpos(2)+dpos(4)/2-figh/2;
    hDlg = figure('Name','Import Parameters','NumberTitle','off','MenuBar','none','ToolBar','none', ...
        'Position',[fx fy figw figh],'WindowStyle','modal','Resize','off');
    % ensure dialog controls use consistent font size
    set(hDlg, 'DefaultUicontrolFontSize', 10, 'DefaultUipanelFontSize', 10);

    ypos = 1-40/360; gap = 36/360;
    % Import Type selector: Quantized vs Raw
    uicontrol('Parent',hDlg,'Style','text','String','Import type:','HorizontalAlignment','left','Position',[10 figh-40 160 20]);
    hImportType = uicontrol('Parent',hDlg,'Style','popupmenu','String',{'Quantized','Raw'},'Position',[180 figh-44 120 24]);
    % set initial import type based on metadata (if any)
    try
        if isfield(params,'importType') && strcmpi(params.importType,'Raw')
            set(hImportType,'Value',2);
        else
            set(hImportType,'Value',1);
        end
    catch
    end

    % Move sample rate up to second row and shift other controls down
    uicontrol('Parent',hDlg,'Style','text','String','Numeric format:','HorizontalAlignment','left','Position',[10 figh-120 160 20],'Tag','lab_num');
    hNum = uicontrol('Parent',hDlg,'Style','popupmenu','String',{'Integer (N bits)','Q format (N bits, frac)'},'Position',[180 figh-124 220 24]);
    uicontrol('Parent',hDlg,'Style','text','String','Sign:','HorizontalAlignment','left','Position',[10 figh-160 160 20],'Tag','lab_sign');
    hSign = uicontrol('Parent',hDlg,'Style','popupmenu','String',{'Unsigned','Signed (Two''s complement)'},'Position',[180 figh-164 220 24]);

    % N bits
    uicontrol('Parent',hDlg,'Style','text','String','N bits (total):','HorizontalAlignment','left','Position',[10 figh-200 160 20],'Tag','lab_nbits');
    hN = uicontrol('Parent',hDlg,'Style','edit','String',num2str(params.Nbits),'Position',[180 figh-204 120 24],'Tag','edit_nbits');
    % frac (for Q)
    uicontrol('Parent',hDlg,'Style','text','String','Frac bits:','HorizontalAlignment','left','Position',[10 figh-240 160 20],'Tag','lab_frac');
    hFrac = uicontrol('Parent',hDlg,'Style','edit','String',num2str(params.frac),'Position',[180 figh-244 120 24],'Tag','edit_frac');

    % vmin/vmax or peak
    uicontrol('Parent',hDlg,'Style','text','String','vmin (for unsigned):','HorizontalAlignment','left','Position',[10 figh-280 160 20],'Tag','lab_vmin');
    hVmin = uicontrol('Parent',hDlg,'Style','edit','String','-1','Position',[180 figh-284 120 24],'Tag','edit_vmin');
    uicontrol('Parent',hDlg,'Style','text','String','vmax (for unsigned):','HorizontalAlignment','left','Position',[10 figh-320 160 20],'Tag','lab_vmax');
    hVmax = uicontrol('Parent',hDlg,'Style','edit','String','1','Position',[180 figh-324 120 24],'Tag','edit_vmax');

    uicontrol('Parent',hDlg,'Style','text','String','Peak (for signed):','HorizontalAlignment','left','Position',[10 figh-280 160 20],'Visible','off','Tag','lab_peak');
    hPeak = uicontrol('Parent',hDlg,'Style','edit','String','1','Position',[180 figh-284 120 24],'Visible','off','Tag','edit_peak');

    % fs (moved up to second row under import type)
    uicontrol('Parent',hDlg,'Style','text','String','Sample rate (Hz):','HorizontalAlignment','left','Position',[10 figh-80 160 20]);
    hFs = uicontrol('Parent',hDlg,'Style','edit','String',num2str(params.fs),'Position',[180 figh-84 120 24],'Tag','edit_fs');

    % bytes per sample (for bin) - shown only if ext == '.bin' or user wants
    hLabB = uicontrol('Parent',hDlg,'Style','text','String','Bytes/sample (bin only):','HorizontalAlignment','left','Position',[10 figh-400 160 20],'Visible','off','Tag','lab_bps');
    hBps = uicontrol('Parent',hDlg,'Style','edit','String','','Position',[180 figh-404 120 24],'Visible','off','Tag','edit_bps');
    if strcmpi(ext,'.bin')
        set(hLabB,'Visible','on'); set(hBps,'Visible','on'); set(hBps,'String','2');
    end

    % OK / Cancel
    uicontrol('Parent',hDlg,'Style','pushbutton','String','OK','Position',[figw-220 10 80 28],'Callback',@okCb);
    uicontrol('Parent',hDlg,'Style','pushbutton','String','Cancel','Position',[figw-120 10 80 28],'Callback',@cancelCb);

    % dynamic visibility callback
    set(hNum,'Callback',@updateVis);
    set(hSign,'Callback',@updateVis);
    set(hImportType,'Callback',@updateVis);
    updateVis();

    uiwait(hDlg);
    if ~isvalid(hDlg)
        cancelled = true; return;
    end

    % collect results from controls
    try
        % import type
        itmp = get(hImportType,'Value'); itms = get(hImportType,'String'); params.importType = itms{itmp};
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
    it = hImportType.String{get(hImportType,'Value')};
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
    % If user chose Raw import, hide encoding-specific controls
    if strcmpi(it,'Raw')
        % hide numeric/sign/nbits/frac/vmin/vmax/peak/bytes-per-sample
        set(findobj(hDlg,'Tag','lab_num'),'Visible','off'); set(hNum,'Visible','off');
        set(findobj(hDlg,'Tag','lab_sign'),'Visible','off'); set(hSign,'Visible','off');
        set(findobj(hDlg,'Tag','lab_nbits'),'Visible','off'); set(hN,'Visible','off');
        set(findobj(hDlg,'Tag','lab_frac'),'Visible','off'); set(hFrac,'Visible','off');
        set(findobj(hDlg,'Tag','lab_vmin'),'Visible','off'); set(hVmin,'Visible','off');
        set(findobj(hDlg,'Tag','lab_vmax'),'Visible','off'); set(hVmax,'Visible','off');
        set(findobj(hDlg,'Tag','lab_peak'),'Visible','off'); set(hPeak,'Visible','off');
        set(findobj(hDlg,'Tag','lab_bps'),'Visible','off'); set(hBps,'Visible','off');
        % leave only sample rate visible for raw imports
        set(findobj(hDlg,'Tag','edit_fs'),'Visible','on');
    else
        % show back encoding controls
        set(findobj(hDlg,'Tag','lab_num'),'Visible','on'); set(hNum,'Visible','on');
        set(findobj(hDlg,'Tag','lab_sign'),'Visible','on'); set(hSign,'Visible','on');
        set(findobj(hDlg,'Tag','lab_nbits'),'Visible','on'); set(hN,'Visible','on');
        set(findobj(hDlg,'Tag','lab_frac'),'Visible','on'); set(hFrac,'Visible','on');
        % show vmin/vmax or peak according to sign selection
        if contains(ss,'Unsigned')
            set(findobj(hDlg,'Tag','lab_vmin'),'Visible','on'); set(hVmin,'Visible','on'); set(findobj(hDlg,'Tag','lab_vmax'),'Visible','on'); set(hVmax,'Visible','on');
            set(findobj(hDlg,'Tag','lab_peak'),'Visible','off'); set(hPeak,'Visible','off');
        else
            set(findobj(hDlg,'Tag','lab_vmin'),'Visible','off'); set(hVmin,'Visible','off'); set(findobj(hDlg,'Tag','lab_vmax'),'Visible','off'); set(hVmax,'Visible','off');
            set(findobj(hDlg,'Tag','lab_peak'),'Visible','on'); set(hPeak,'Visible','on');
        end
        % show bytes-per-sample only if ext==.bin
        if strcmpi(ext,'.bin')
            set(findobj(hDlg,'Tag','lab_bps'),'Visible','on'); set(hBps,'Visible','on');
        else
            set(findobj(hDlg,'Tag','lab_bps'),'Visible','off'); set(hBps,'Visible','off');
        end
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

function s = getParamRaw(labelStr, default)
    % Return the raw string from the parameter edit control (or default string)
    tag = labelToTag(labelStr);
    h = findobj(hParamPanel,'Tag',tag);
    if isempty(h)
        s = num2str(default);
    else
        s = get(h,'String');
    end
end

function arr = parseNumericArray(strOrDefault, default)
    % Parse a user-entered string which may contain a scalar or MATLAB array
    % examples: '1', '[1 0.5]', '1,2,3', ' [ 1; 2 ]'
    try
        if isempty(strOrDefault)
            arr = default;
            return;
        end
        if isnumeric(strOrDefault)
            arr = strOrDefault;
            return;
        end
        s = strtrim(strOrDefault);
        % Replace commas with spaces so str2num handles both
        s2 = regexprep(s,',',' ');
        % Try str2num which accepts array notation
        arrTmp = str2num(s2); %#ok<ST2NM>
        if isempty(arrTmp)
            % fallback to single number
            v = str2double(s);
            if isnan(v)
                arr = default;
            else
                arr = v;
            end
        else
            arr = arrTmp(:)'; % return row vector
        end
    catch
        arr = default;
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
    % Delegate to shared import handler which covers both file and workspace
    try
        performImport('file', fullpath, [], ext, params);
    catch ME
        set(hStatus,'String',['Import failed: ' ME.message]);
    end
end

function performImport(sourceType, source, payload, ext, params)
    % Unified import handler for 'file' or 'workspace'
    % sourceType: 'file' or 'workspace'
    % source: fullpath or workspace variable name (string)
    % payload: for workspace imports, the variable data; for file imports, pass []
    % ext: file extension for file imports (e.g. '.csv'); for workspace, can be ''
    % params: import parameters returned by askImportParams
    if nargin<5, params = struct(); end
    try
        % raw import path
        if isfield(params,'importType') && strcmpi(params.importType,'Raw')
            if strcmpi(sourceType,'file')
                switch lower(ext)
                    case '.csv'
                        M = readmatrix(source);
                        y = double(M(:)');
                    case '.mat'
                        S = load(source);
                        flds = fieldnames(S); y = [];
                        for k=1:numel(flds)
                            v = S.(flds{k});
                            if isnumeric(v) && (isvector(v) || ismatrix(v))
                                y = double(v(:)'); break;
                            end
                        end
                        if isempty(y), error('No numeric variable found in MAT file'); end
                    otherwise
                        error('Raw import not supported for %s files', ext);
                end
            else
                % workspace payload expected
                if isempty(payload) || ~isnumeric(payload)
                    error('Workspace variable not numeric for Raw import');
                end
                y = double(payload(:)');
            end
            % store and preview
            importedData.floatY = y;
            importedData.intVals = [];
            if strcmpi(sourceType,'file'), importedData.fileName = source; else importedData.fileName = ['workspace:' source]; end
            importedData.fs = params.fs;
            if isempty(importedData.fs) || isnan(importedData.fs) || importedData.fs<=0, importedData.fs = 48000; end
            importedData.t = (0:numel(y)-1)/importedData.fs;
            importedData.info = struct('type','Imported (raw)');
            cla(hAx);
            if numel(unique(y))<=2, stairs(hAx, importedData.t, y); else plot(hAx, importedData.t, y); end
            if strcmpi(sourceType,'file'), title(hAx,['Imported (raw): ' source]); set(hStatus,'String',['Imported raw data (' num2str(numel(y)) ' samples) from ' source]); else title(hAx,['Imported (raw): workspace:' source]); set(hStatus,'String',['Imported raw variable ''' source ''' from workspace (' num2str(numel(y)) ' samples)']); end
            return;
        end

        % Quantized path: parse ints (from file) or accept/derive ints (from workspace)
        if strcmpi(sourceType,'file')
            % parse file into integer vector
            switch lower(ext)
                case {'.hex','.mem'}
                    txt = fileread(source);
                    lines = regexp(txt,'\r?\n','split'); vals = [];
                    for k=1:numel(lines)
                        s = strtrim(lines{k}); if isempty(s), continue; end
                        try s2 = regexprep(s,'^0x',''); v = hex2dec(s2); vals(end+1)=v; catch; end
                    end
                    intVals = uint64(vals);
                case '.coe'
                    txt = fileread(source);
                    m = regexp(txt,'memory_initialization_vector\s*=\s*([^;]+);','tokens','ignorecase');
                    if isempty(m), error('COE: cannot find initialization vector'); end
                    vec = m{1}{1}; parts = regexp(vec,',','split'); vals = zeros(1,numel(parts)); for k=1:numel(parts), vals(k)=hex2dec(strtrim(parts{k})); end
                    intVals = uint64(vals);
                case '.mif'
                    fid = fopen(source,'r'); txt = textscan(fid,'%s','Delimiter','\n'); fclose(fid); lines = txt{1}; vals = []; inContent=false;
                    for k=1:numel(lines)
                        s = strtrim(lines{k}); if isempty(s), continue; end
                        if startsWith(upper(s),'CONTENT BEGIN'), inContent=true; continue; end
                        if ~inContent, continue; end
                        if startsWith(upper(s),'END'), break; end
                        parts = regexp(s,':','split'); if numel(parts)>=2, dataPart = parts{2}; dataPart = regexprep(dataPart,';',''); dataPart = strtrim(dataPart); try vals(end+1)=hex2dec(dataPart); catch; end; end
                    end
                    intVals = uint64(vals);
                case '.csv'
                    M = readmatrix(source); intVals = uint64(M(:)');
                case '.bin'
                    fid = fopen(source,'r'); data = fread(fid,'uint8'); fclose(fid); n=numel(data);
                    bps = params.bps; if isempty(bps) || isnan(bps) || bps<1, bps=ceil(params.Nbits/8); end
                    if mod(n,bps)~=0, warning('File size not a multiple of bytes per sample'); end
                    nsamples = floor(n/bps); vals = zeros(1,nsamples,'uint64');
                    for i=1:nsamples
                        idx2 = (i-1)*bps + (1:bps); v = uint64(0);
                        for j=1:bps, v = bitor(bitshift(v,8), uint64(data(idx2(j)))); end
                        vals(i)=v;
                    end
                    intVals = uint64(vals);
                otherwise
                    error('Unsupported extension: %s', ext);
            end
            srcName = source;
        else
            % workspace payload -> either integer vector or float to quantize
            if isinteger(payload) || all(mod(payload(:),1)==0)
                intVals = uint64(payload(:)');
            else
                y = double(payload(:)');
                encType = params.encodeType; Nbits = params.Nbits; frac = params.frac;
                intVals = encodeSignalToIntegers(y, encType, Nbits, frac);
            end
            srcName = ['workspace:' source];
        end

        % prepare params2 and call shared handler
        numericSel = params.numericSel; signSel = params.signSel; encodeType = params.encodeType; Nbits = params.Nbits; frac = params.frac; vmin = params.vmin; vmax = params.vmax; peak = params.peak; fs = params.fs; bps = params.bps;
        params2 = struct('numericSel',numericSel,'signSel',signSel,'encodeType',encodeType,'Nbits',Nbits,'frac',frac,'vmin',vmin,'vmax',vmax,'peak',peak,'fs',fs,'bps',bps);
        handleImportedInts(uint64(intVals), srcName, params2);
    catch ME
        rethrow(ME);
    end
end

function exportCallback(~,~)
    % 判断 Quantize 按钮状态
    hBtn = findobj(hFig,'Tag','btn_quantize');
    quantOn = ~isempty(hBtn) && ishandle(hBtn) && get(hBtn,'Value');
    % 导出浮点（原始）还是量化整数
    exportFloat = ~quantOn; % Quantize=ON 导出量化数据，OFF 导出原始数据
    % 选择文件名和格式
    filters = {'*.hex;*.mem;*.bin;*.coe;*.mif;*.csv','All supported files (*.hex,*.mem,*.bin,*.coe,*.mif,*.csv)';
               '*.hex','HEX (*.hex)';'*.mem','MEM (*.mem)';'*.bin','BIN (*.bin)';'*.coe','COE (*.coe)';'*.mif','MIF (*.mif)';'*.csv','CSV (*.csv)'};
    [fileName, filePath, filterIdx] = uiputfile(filters,'Save as');
    if isequal(fileName,0)
        set(hStatus,'String','Export cancelled'); return;
    end
    fullpath = fullfile(filePath,fileName);
    [~,~,ext] = fileparts(fileName); ext = lower(ext);
    if isempty(ext) && ~isempty(filterIdx)
        extlist = {'.hex','.hex','.mem','.bin','.coe','.mif','.csv'};
        if filterIdx>=1 && filterIdx<=numel(extlist)
            ext = extlist{filterIdx};
        else
            ext = '.hex';
        end
    end
    if exportFloat
        % 导出原始浮点数据（CSV格式，或其它格式只导出浮点）
        if isempty(importedData.floatY)
            set(hStatus,'String','No original data to export.'); return;
        end
        try
            fid = fopen(fullpath,'w');
            if fid<0, error('Cannot open file for writing'); end
            for k=1:numel(importedData.floatY)
                fprintf(fid,'%.10g\n',importedData.floatY(k));
            end
            fclose(fid);
            set(hStatus,'String',['Exported original (float) data to ' fullpath]);
        catch ME
            set(hStatus,'String',['Write error: ' ME.message]);
        end
    else
        % 导出量化整数（按当前编码参数编码 floatY 或用 intVals）
        try
            [encType, N, frac] = getEncodingParams();
            if ~isempty(importedData.floatY)
                intVals = encodeSignalToIntegers(importedData.floatY, encType, N, frac);
            elseif ~isempty(importedData.intVals)
                intVals = importedData.intVals;
            else
                set(hStatus,'String','No quantized data to export.'); return;
            end
            writeOutputFile(fullpath, intVals, N, ext);
            set(hStatus,'String',['Exported quantized (integer) data to ' fullpath]);
        catch ME
            set(hStatus,'String',['Write error: ' ME.message]);
        end
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
    % Ask user for import params (same dialog as file import)
    [params, cancelled] = askImportParams([], '', 'workspace');
    if cancelled
        set(hStatus,'String','Import cancelled');
        return;
    end
    % Delegate to shared import worker
    try
        performImport('workspace', vname, data, '', params);
    catch ME
        set(hStatus,'String',['Import failed: ' ME.message]);
    end
end

function exportToWorkspaceCallback(~,~)
    % 判断 Quantize 按钮状态
    hBtn = findobj(hFig,'Tag','btn_quantize');
    quantOn = ~isempty(hBtn) && ishandle(hBtn) && get(hBtn,'Value');
    exportFloat = ~quantOn;
    prompt = {'Variable name in base workspace:'};
    def = {'exported_signal'};
    answ = inputdlg(prompt,'Export to Workspace',[1 50],def);
    if isempty(answ), set(hStatus,'String','Export to workspace cancelled'); return; end
    vname = answ{1};
    try
        if exportFloat
            if ~isempty(importedData.floatY)
                assignin('base', vname, importedData.floatY);
                set(hStatus,'String',['Exported original (float) data to workspace variable ''' vname '''']);
            else
                set(hStatus,'String','No original data to export.');
            end
        else
            [encType, N, frac] = getEncodingParams();
            if ~isempty(importedData.floatY)
                intVals = encodeSignalToIntegers(importedData.floatY, encType, N, frac);
            elseif ~isempty(importedData.intVals)
                intVals = importedData.intVals;
            else
                set(hStatus,'String','No quantized data to export.'); return;
            end
            assignin('base', vname, intVals);
            set(hStatus,'String',['Exported quantized (integer) data to workspace variable ''' vname '''']);
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
            % Allow amplitude/frequency/phase to be scalars or arrays. If arrays
            % are provided (e.g. [1 0.5] for amplitude), multiple sine components
            % are generated and summed.
            A_raw = getParamRaw('Amplitude','1');
            f_raw = getParamRaw('Frequency (Hz)','50');
            ph_raw = getParamRaw('Phase (deg)','0');
            % sample rate may be tagged as 'srate' or 'prbs_fs'
            hfs = findobj(hParamPanel,'Tag','srate'); if isempty(hfs), hfs = findobj(hParamPanel,'Tag','prbs_fs'); end
            if isempty(hfs), fs = 48000; else fs = str2double(get(hfs,'String')); end
            duration = getParamValue('Duration (s)',10);
            Ns = max(1, round(duration * fs));
            t = (0:Ns-1)/fs;
            % parse possible arrays
            A_arr = parseNumericArray(A_raw, 1);
            f_arr = parseNumericArray(f_raw, 50);
            ph_arr = parseNumericArray(ph_raw, 0);
            % ensure row vectors
            if isscalar(A_arr), A_arr = A_arr(:)'; end
            if isscalar(f_arr), f_arr = f_arr(:)'; end
            if isscalar(ph_arr), ph_arr = ph_arr(:)'; end
            nComp = max([numel(A_arr), numel(f_arr), numel(ph_arr)]);
            if nComp <= 0, nComp = 1; end
            % broadcast scalars to match components
            if numel(A_arr) == 1, A_arr = repmat(A_arr,1,nComp); end
            if numel(f_arr) == 1, f_arr = repmat(f_arr,1,nComp); end
            if numel(ph_arr) == 1, ph_arr = repmat(ph_arr,1,nComp); end
            % Sum multiple sine components
            y = zeros(1, Ns);
            for k = 1:nComp
                y = y + A_arr(k) .* sin(2*pi*f_arr(k).*t + deg2rad(ph_arr(k)));
            end
            % apply offset if provided (offset may be scalar or a time-vector)
            off_raw = getParamRaw('Offset','0');
            off_arr = parseNumericArray(off_raw, 0);
            if numel(off_arr) == 1
                y = y + off_arr;
            elseif numel(off_arr) == Ns
                y = y + off_arr(:)';
            else
                % If offset is a short vector, try to broadcast first element
                y = y + off_arr(1);
            end
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
        % store reconstructed waveform into shared importedData (with time vector)
        try
            importedData.floatY = yRestored;
            if isfield(importedData,'fs') && ~isempty(importedData.fs)
                importedData.t = (0:numel(yRestored)-1)/importedData.fs;
            else
                importedData.t = (0:numel(yRestored)-1);
            end
            importedData.info = struct('type','Imported');
        catch
        end
        % prefer plotting against time vector if available and matching length
        useTime = isfield(importedData,'t') && ~isempty(importedData.t) && numel(importedData.t)==numel(yRestored);
        if numel(unique(yRestored))<=2
            if useTime
                stairs(hAx, importedData.t, yRestored);
            else
                stairs(hAx, yRestored);
            end
        else
            if useTime
                plot(hAx, importedData.t, yRestored);
            else
                plot(hAx, yRestored);
            end
        end
    catch
        % fallback: plot raw integer values
        try
            importedData.floatY = double(importedData.intVals);
            importedData.t = (0:numel(importedData.intVals)-1);
            importedData.info = struct('type','Imported (raw)');
        catch
        end
        % fallback plotting for raw ints also prefers time vector
        useTime2 = isfield(importedData,'t') && ~isempty(importedData.t) && numel(importedData.t)==numel(importedData.intVals);
        if numel(unique(importedData.intVals))<=2
            if useTime2
                stairs(hAx, importedData.t, double(importedData.intVals));
            else
                stairs(hAx, double(importedData.intVals));
            end
        else
            if useTime2
                plot(hAx, importedData.t, double(importedData.intVals));
            else
                plot(hAx, double(importedData.intVals));
            end
        end
    end
    title(hAx,['Imported: ' sourceName]);
end
% Nested callback: Show or hide the quantized overlay without regenerating the full signal when possible
function toggleQuantize(src,~)
    try
        if nargin>=1 && ishandle(src)
            val = get(src,'Value');
        else
            hBtn = findobj(hFig,'Tag','btn_quantize');
            val = ~isempty(hBtn) && ishandle(hBtn) && get(hBtn,'Value');
        end
    catch
        val = false;
    end

    if val
        % try to find existing original preview data (use hAx from parent scope)
        hOrig = findobj(hAx,'Tag','orig_preview');
        if isempty(hOrig)
            % if no plotted original, try to use stored importedData.floatY
            if isfield(importedData,'floatY') && ~isempty(importedData.floatY)
                x = importedData.t;
                y = importedData.floatY;
            else
                % nothing to overlay yet -- generate preview which will draw overlay when toggle is on
                try
                    generatePreview();
                catch
                end
                return;
            end
        else
            try
                x = get(hOrig,'XData'); y = get(hOrig,'YData');
            catch
                x = []; y = [];
            end
        end
        try
            [encType, N, frac] = getEncodingParams();
            intQ = encodeSignalToIntegers(y, encType, N, frac);
            yq = reconstructFromInts(y, double(intQ), encType, N, frac);
            oldQ = findobj(hAx,'Tag','quant_preview'); delete(oldQ);
            hold(hAx,'on');
            hQ = plot(hAx, x, yq, '--r', 'LineWidth', 1.0);
            try set(hQ,'Tag','quant_preview'); catch; end
            legend(hAx,{'Original','Quantized'},'Location','best');
            hold(hAx,'off');
        catch
            % ignore overlay errors
        end
    else
        % remove overlay
        try
            oldQ = findobj(hAx,'Tag','quant_preview'); delete(oldQ);
        catch
        end
    end
end

% Close main function
end