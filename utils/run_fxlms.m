function [t,d,y_s,e,W_hist,w,params_out] = run_fxlms(params)
% RUN_FXLMS 运行基于参数的样本级 FXLMS 仿真（可被 GUI 调用）
% 输入: params 结构体，字段（均有默认值）：
%   .noiseType ('white'|'band'|'file')
%   .noiseFile (当 noiseType=='file' 时使用)
%   .fs, .duration, .Lw, .mu, .useSecondaryEstimate, .saveResults
% 输出: t,d,y_s,e,W_hist,w,params_out

% 兼容性与健壮性检查
if ~isfield(params,'noiseType'), params.noiseType = 'band'; end
if ~isfield(params,'noiseFile'), params.noiseFile = 'data/whitenoise200-2kHz.bin'; end
if ~isfield(params,'fs'), params.fs = 48000; end
if ~isfield(params,'duration'), params.duration = 8; end
if ~isfield(params,'Lw'), params.Lw = 512; end
if ~isfield(params,'mu'), params.mu = 5e-4; end
if ~isfield(params,'useSecondaryEstimate'), params.useSecondaryEstimate = true; end
if ~isfield(params,'saveResults'), params.saveResults = true; end

fs = params.fs;
duration = params.duration;
Lw = params.Lw;
mu = params.mu;

% 尝试加载 data/ 下识别结果（次级/主路径）
P = []; S = [];
try
    % Priority 1: user provided explicit secondary SysID file (S)
    if isfield(params,'sysidSecondaryFile') && ~isempty(params.sysidSecondaryFile) && exist(params.sysidSecondaryFile,'file')
        tmp = load(params.sysidSecondaryFile);
        if isfield(tmp,'s') && isfield(tmp.s,'w')
            S = tmp.s.w(:);
            if isfield(tmp.s,'fs'), fs = tmp.s.fs; end
        end
    else
        % Fallback: search in provided sysidDir or default data/ for latest LMS_SYSID*.mat
        if isfield(params,'sysidDir') && ~isempty(params.sysidDir)
            sysdir = params.sysidDir;
        else
            sysdir = fullfile('data');
        end
        dlist = dir(fullfile(sysdir, 'LMS_SYSID*.mat'));
        if ~isempty(dlist)
            [~, idx] = max([dlist.datenum]);
            tmpfile = fullfile(dlist(idx).folder, dlist(idx).name);
            tmp = load(tmpfile);
            if isfield(tmp,'s') && isfield(tmp.s,'w')
                S = tmp.s.w(:); fs = tmp.s.fs; end
        end
    end
catch
    % ignore
end
if isempty(S)
    S = fir1(64, 0.2);
end
try
    % Priority 1: user provided explicit primary SysID file (P)
    if isfield(params,'sysidPrimaryFile') && ~isempty(params.sysidPrimaryFile) && exist(params.sysidPrimaryFile,'file')
        tmp2 = load(params.sysidPrimaryFile);
        if isfield(tmp2,'s') && isfield(tmp2.s,'w'), P = tmp2.s.w(:); end
    else
        % Fallback: search in sysdir (set above) for LMS_SYSID*prim*.mat
        if ~exist('sysdir','var') || isempty(sysdir)
            if isfield(params,'sysidDir') && ~isempty(params.sysidDir)
                sysdir = params.sysidDir;
            else
                sysdir = fullfile('data');
            end
        end
        d2 = dir(fullfile(sysdir, 'LMS_SYSID*prim*.mat'));
        if ~isempty(d2)
            [~, idx2] = max([d2.datenum]); tmp2file = fullfile(d2(idx2).folder, d2(idx2).name);
            tmp2 = load(tmp2file);
            if isfield(tmp2,'s') && isfield(tmp2.s,'w'), P = tmp2.s.w(:); end
        end
    end
catch
    % ignore
end
if isempty(P)
    P = fir1(80, [60 3000]/(fs/2), 'bandpass');
end

S_est = S;

% 生成参考信号 r
% 支持外部传入 params.r（优先），否则按 noiseType 生成/读取
if isfield(params,'r') && ~isempty(params.r)
    r = params.r(:);
    N = length(r);
else
    N = round(duration * fs);
    switch lower(params.noiseType)
        case 'white'
            r = randn(N,1);
        case 'band'
            r0 = randn(N,1); bp = fir1(512, [200 2000]/(fs/2), 'bandpass'); r = filter(bp,1,r0);
        case 'file'
            if exist(params.noiseFile,'file')
                if endsWith(params.noiseFile,'.bin','IgnoreCase',true)
                    r = readFromBIN(params.noiseFile); r = r(:);
                else
                    [r, rfs] = audioread(params.noiseFile);
                    if exist('rfs','var') && rfs~=fs, r = resample(r, fs, rfs); end
                end
                if length(r) < N
                    N = length(r);
                    r = r(1:N);
                else
                    r = r(1:N);
                end
            else
                error('noise file not found: %s', params.noiseFile);
            end
        otherwise
            error('Unknown noiseType: %s', params.noiseType);
    end
    % 归一化参考信号功率，便于对比
    r = r / rms(r);
end

% 主噪声 d
d_full = conv(r, P); d = d_full(1:N);

% optional progress callback (params.progressFcn) -- set up now that N is known
progressFcn = [];
if isfield(params,'progressFcn') && isa(params.progressFcn,'function_handle')
    progressFcn = params.progressFcn;
end
progressStep = max(1,floor(N/100));

% 初始化
w = zeros(Lw,1); W_hist = zeros(Lw,N); e = zeros(N,1); y = zeros(N,1); y_s = zeros(N,1);
x_buf = zeros(max([Lw,length(S_est)]),1); y_buf = zeros(length(S),1);

for n=1:N
    xn = r(n);
    x_buf = [xn; x_buf(1:end-1)];
    x_vec = x_buf(1:Lw);
    yn = w' * x_vec; y(n) = yn;
    y_buf = [yn; y_buf(1:end-1)]; ys_n = S' * y_buf(1:length(S)); y_s(n) = ys_n;
    e(n) = d(n) - ys_n;
    % filtered-x
    x_buf_est = x_buf(1:length(S_est)); filt_xn = S_est' * x_buf_est;
    if n==1, fx_buf = zeros(Lw,1); end
    fx_buf = [filt_xn; fx_buf(1:end-1)];
    w = w + mu * e(n) * fx_buf;
    W_hist(:,n) = w;
    % report progress occasionally
    if ~isempty(progressFcn) && (mod(n,progressStep)==0 || n==N)
        try
            progressFcn(n / N);
        catch
        end
    end
end

t = (0:N-1)'/fs;
params_out = params; params_out.fs = fs; params_out.P = P; params_out.S = S;

if params.saveResults
    ts = datestr(datetime('now'),'yyyy-mm-dd_HHMMSS'); outname = fullfile('data', ['fxlms_result_', ts, '.mat']);
    save(outname, 'w','W_hist','e','y','y_s','d','r','P','S','S_est','fs','params');
    fprintf('run_fxlms: saved results to %s\n', outname);
end
end
