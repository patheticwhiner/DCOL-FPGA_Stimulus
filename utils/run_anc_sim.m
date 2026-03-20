function [t,d,y_s,e,W_hist,w,params_out] = run_anc_sim(params)
% RUN_ANC_SIM Generic Simulator for Single-Channel ANC
%
% Performs the environment setup (loading paths, generating noise) and
% executes a control loop using a pluggable algorithm strategy.
%
% Inputs:
%   params : Structure with configuration
%       .fs, .duration      : Sampling rate and time
%       .sysidPrimaryFile   : (Optional) Path to P model
%       .sysidSecondaryFile : (Optional) Path to S model
%       .noiseType, etc.    : Noise generation settings
%       .createAlgFcn       : Function handle @(S_est, params) -> alg_struct
%                             Must return struct with .Lw, .initFcn, .stepFcn
%
% Outputs:
%   t, d, y_s, e : Time-domain signals
%   W_hist       : Weight history (if tracked)
%   w            : Final weights
%   params_out   : Updated parameters

    % 1. --- Parameter defaults (Environment) ---
    if ~isfield(params,'fs'), params.fs = 48000; end
    if ~isfield(params,'duration'), params.duration = 8; end
    if ~isfield(params,'noiseType'), params.noiseType = 'band'; end
    if ~isfield(params,'saveResults'), params.saveResults = true; end
    if ~isfield(params,'useSecondaryEstimate'), params.useSecondaryEstimate = true; end

    fs = params.fs;

    % 2. --- Load Environment Models (P & S) ---
    P = []; S = [];

    % Load Secondary Path S
    try
        if isfield(params,'sysidSecondaryFile') && ~isempty(params.sysidSecondaryFile) && exist(params.sysidSecondaryFile,'file')
            tmp = load(params.sysidSecondaryFile);
            if isfield(tmp,'s') && isfield(tmp.s,'w'), S = tmp.s.w(:); end
        else
            % Fallback search
            sysdir = 'data';
            if isfield(params,'sysidDir') && ~isempty(params.sysidDir), sysdir = params.sysidDir; end
            dlist = dir(fullfile(sysdir, 'LMS_SYSID*.mat'));
            if ~isempty(dlist)
                [~, idx] = max([dlist.datenum]);
                tmp = load(fullfile(dlist(idx).folder, dlist(idx).name));
                if isfield(tmp,'s') && isfield(tmp.s,'w'), S = tmp.s.w(:); end
            end
        end
    catch
        % ignore
    end
    if isempty(S), S = fir1(64, 0.2)'; end % Default dummy path
    S = S(:);

    % Load Primary Path P
    try
        if isfield(params,'sysidPrimaryFile') && ~isempty(params.sysidPrimaryFile) && exist(params.sysidPrimaryFile,'file')
            tmp = load(params.sysidPrimaryFile);
            if isfield(tmp,'s') && isfield(tmp.s,'w'), P = tmp.s.w(:); end
        else
            sysdir = 'data';
            if isfield(params,'sysidDir') && ~isempty(params.sysidDir), sysdir = params.sysidDir; end
            d2 = dir(fullfile(sysdir, 'LMS_SYSID*prim*.mat'));
            if ~isempty(d2)
                [~, idx] = max([d2.datenum]);
                tmp = load(fullfile(d2(idx).folder, d2(idx).name));
                if isfield(tmp,'s') && isfield(tmp.s,'w'), P = tmp.s.w(:); end
            end
        end
    catch
        % ignore
    end
    if isempty(P), P = fir1(80, [60 3000]/(fs/2), 'bandpass')'; end
    P = P(:);

    % Load Primary-to-Reference Path (PriRef)
    % Maps noise source r to reference microphone signal x (without feedback)
    PriRef = [];
    try
        if isfield(params,'sysidPriRefFile') && ~isempty(params.sysidPriRefFile) && exist(params.sysidPriRefFile,'file')
            tmp = load(params.sysidPriRefFile);
            if isfield(tmp,'s') && isfield(tmp.s,'w'), PriRef = tmp.s.w(:); end
        end
    catch
        % ignore
    end
    if isempty(PriRef), PriRef = 1.0; end % Default to identity (x = r)
    PriRef = PriRef(:);

    % Load Secondary-to-Reference Path (SecRef)
    % Feedback path from control output y to reference microphone x
    SecRef = [];
    try
        if isfield(params,'sysidSecRefFile') && ~isempty(params.sysidSecRefFile) && exist(params.sysidSecRefFile,'file')
            tmp = load(params.sysidSecRefFile);
            if isfield(tmp,'s') && isfield(tmp.s,'w'), SecRef = tmp.s.w(:); end
        end
    catch
        % ignore
    end
    if isempty(SecRef), SecRef = 0.0; end % Default to no feedback
    SecRef = SecRef(:);

    % Define S_est (Controller's model of S)
    if params.useSecondaryEstimate
        S_est = S; % Perfect estimation case for now
    else
        S_est = [1; zeros(length(S)-1,1)]; % Unit impulse (no model)
    end


    % 3. --- Generate Signals (r, d) ---
    if isfield(params,'r') && ~isempty(params.r)
        r = params.r(:);
        N = length(r);
    else
        N = round(params.duration * fs);
        switch lower(params.noiseType)
            case 'white'
                r = randn(N,1);
            case 'band'
                r0 = randn(N,1); bp = fir1(512, [200 2000]/(fs/2), 'bandpass'); r = filter(bp,1,r0);
            case 'file'
                if isfield(params,'noiseFile') && exist(params.noiseFile,'file')
                     if endsWith(params.noiseFile,'.bin','IgnoreCase',true)
                        r = readFromBIN(params.noiseFile);
                    else
                        [r, rfs] = audioread(params.noiseFile);
                        if exist('rfs','var') && rfs~=fs, r = resample(r, fs, rfs); end
                    end
                    if length(r)>N, r=r(1:N); else, N=length(r); end
                else
                    error('Noise file not found');
                end
            otherwise
                r = randn(N,1);
        end
        r = r(:) / (std(r) + eps); % Normalize
    end

    % Pre-calculate disturbance d = P * r
    d_full = conv(r, P);
    d = d_full(1:N);

    % Pre-calculate source component of reference signal x_source = PriRef * r
    % If PriRef is identity (default), x_source == r
    x_source_full = conv(r, PriRef);
    x_source = x_source_full(1:N);


    % 4. --- Initialize Algorithm Strategy ---
    if ~isfield(params, 'createAlgFcn')
        error('params.createAlgFcn is required for run_anc_sim');
    end

    % Instantiate algorithm
    alg = params.createAlgFcn(S_est, params);

    % Validate alg structure
    if ~isfield(alg,'Lw') || ~isfield(alg,'initFcn') || ~isfield(alg,'stepFcn')
        error('Algorithm structure must contain .Lw, .initFcn and .stepFcn');
    end

    Lw = alg.Lw;
    w = zeros(Lw, 1);
    alg_state = alg.initFcn();


    % 5. --- Simulation Loop Preparation ---
    W_hist = zeros(Lw, N);
    e = zeros(N, 1);
    y = zeros(N, 1);
    y_s = zeros(N, 1);

    % Buffers
    % x_buf needs to accommodate:
    % - Controller filter length (Lw)
    % - Secondary path length (length(S))
    % - Algorithm lookback (handled dynamically? FxLMS needs length(S_est) of x)
    len_S = length(S);
    len_S_est = length(S_est);
    max_buf_req = max([Lw, len_S, len_S_est]);

    x_buf = zeros(max_buf_req, 1);
    
    % y_buf accounts for Secondary Path (S) and Secondary-to-Reference Path (SecRef)
    len_SecRef = length(SecRef);
    max_y_buf_req = max(len_S, len_SecRef);
    y_buf = zeros(max_y_buf_req, 1);

    % Progress Tracking
    progressFcn = [];
    if isfield(params,'progressFcn'), progressFcn = params.progressFcn; end
    progressStep = max(1, floor(N/100));


    % 6. --- Main Loop ---
    for n = 1:N
        % 6.1 Environment: Reference Update
        % Calculate Feedback component from Secondary Source to Reference Mic
        % x(n) = (PriRef * r)(n) + (SecRef * y)(n)
        % Since y(n) is computed based on x(n), we assume direct term SecRef(1)*y(n) is negligible or
        % modeled as 0 for causality in this loop structure (using previous y values).
        fb_val = 0;
        if len_SecRef > 0
             % y_buf holds [y(n-1); y(n-2); ...]
             % Align with SecRef taps: SecRef(1)*0 + SecRef(2)*y(n-1) + ...
             fb_vec = [0; y_buf]; 
             fb_val = SecRef' * fb_vec(1:len_SecRef);
        end
        
        xn_env = x_source(n) + fb_val;

        % Determine controller input (Internal Model or External)
        if isfield(alg, 'getRefFcn')
             [xn_ctrl, alg_state] = alg.getRefFcn(xn_env, alg_state);
        else
             xn_ctrl = xn_env;
        end
        x_buf = [xn_ctrl; x_buf(1:end-1)];

        % 6.2 Controller: Generate Output y(n)
        % y(n) = w(n)' * x(n)
        % Standard dot product
        x_vec_Lw = x_buf(1:Lw);
        yn = w' * x_vec_Lw;
        y(n) = yn;

        % 6.3 Environment: Secondary Path Simulation
        % Update buffer and calculate y_s(n) = S * y_buf
        y_buf = [yn; y_buf(1:end-1)];
        ys_n = S' * y_buf(1:len_S);
        y_s(n) = ys_n;

        % 6.4 Environment: Error Calculation
        en = d(n) - ys_n;
        e(n) = en;

        % 6.5 Algorithm: Update Weights
        % [w_new, state_new] = alg.step(w, x_buf, e, state, yn)
        [w, alg_state] = alg.stepFcn(w, x_buf, en, alg_state, yn);

        % 6.6 Logging
        W_hist(:, n) = w;

        if ~isempty(progressFcn) && mod(n, progressStep) == 0
            progressFcn(n/N);
        end
    end

    % 7. --- Finalize ---
    t = (0:N-1)'/fs;

    params_out = params;
    params_out.fs = fs;
    params_out.P = P;
    params_out.S = S;
    params_out.S_est = S_est;

    if isfield(params,'saveResults') && params.saveResults
        ts = datestr(datetime('now'),'yyyy-mm-dd_HHMMSS');
        outname = fullfile('data', ['anc_sim_result_', ts, '.mat']);
        save(outname, 'w', 'W_hist', 'e', 'y', 'y_s', 'd', 'r', 'fs', 'params');
        fprintf('run_anc_sim: saved results to %s\n', outname);
    end

end
