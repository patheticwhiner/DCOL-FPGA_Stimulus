function bin_to_wav(rootDir, fs, numChannels, outDir, enablePlot)
% bin_to_wav  批量读取 Q1.23 .bin 数据并转换为 .wav
% 
% 用法示例：
%   bin_to_wav();                               % 默认处理
%   bin_to_wav(..., 'visualize', true);         % 伪代码，实际请按位置参数传递
%   bin_to_wav('e:/FPGA_Stimulus/exp_data', 48000, 1, [], true); % 开启绘图验证
%
% 参数：
%   rootDir     - 搜索的根目录
%   fs          - 采样率 (默认 48000)
%   numChannels - 声道数 (默认 1)
%   outDir      - 输出目录 (默认 rootDir/wav)
%   enablePlot  - 是否绘制波形图进行验证 (true/false, 默认 false)
%
% 说明：
% - 自动跳过文件名或路径中包含“coeff”/“Coeffs”的 .bin 文件；
% - 也会检查文件前2KB是否包含 ASCII 文本“Coeffs”，如有则跳过该文件；
% - 自动识别两种常见格式：
%     1) 24位打包（每样本3字节，大端）
%     2) 32位整型（每样本4字节，大端）并做合理缩放推断
% - 将 Q1.23 转换为 double [-1, 1] 后写出 .wav（24-bit 存储）。
%
% 注意：若实际数据包含多声道交织，请设置 numChannels > 1。

if nargin < 1 || isempty(rootDir), rootDir = pwd; end
if nargin < 2 || isempty(fs), fs = 48000; end
if nargin < 3 || isempty(numChannels), numChannels = 1; end
if nargin < 4 || isempty(outDir), outDir = fullfile(rootDir, 'wav'); end
if nargin < 5 || isempty(enablePlot), enablePlot = false; end

if ~isfolder(rootDir)
    error('根目录不存在：%s', rootDir);
end
if ~isfolder(outDir)
    mkdir(outDir);
end

% 规范化 rootDir 分隔符，以便正确计算相对路径
rootDir = strrep(rootDir, '\', '/');
if ~isempty(rootDir) && rootDir(end) == '/'
    rootDir = rootDir(1:end-1);
end

% 递归找到所有 .bin 文件
files = dir(fullfile(rootDir, '**', '*.bin'));
if isempty(files)
    fprintf('[Info] 未在 %s 下找到任何 .bin 文件。\n', rootDir);
    return;
end

fprintf('[Info] 将处理 %d 个 .bin 文件（跳过 Coeffs）。\n', numel(files));

for k = 1:numel(files)
    f = files(k);
    inPath = fullfile(f.folder, f.name);
    
    % 统一路径分隔符并计算相对路径
    inPathUnified = strrep(inPath, '\', '/');
    if strncmpi(inPathUnified, rootDir, length(rootDir))
        relPath = inPathUnified(length(rootDir)+1:end);
        if ~isempty(relPath) && relPath(1) == '/'
            relPath = relPath(2:end);
        end
    else
        % 无法提取相对路径时（罕见），退回到仅文件名
        relPath = f.name;
    end

    % 跳过文件名/路径包含 coeff/coefs/coeffs 的
    if contains(lower(inPath), 'coeff')
        fprintf('[Skip] 命名匹配 Coeffs：%s\n', relPath);
        continue;
    end

    % 跳过内容前缀检测到 ASCII "Coeffs" 的
    if looks_like_coeff_file(inPath)
        fprintf('[Skip] 内容检测 Coeffs：%s\n', relPath);
        continue;
    end

    try
        % 读取 Q1.23 样本（支持24位打包或32位）
        x = read_q1_23_file(inPath);
        if isempty(x)
            fprintf('[Warn] 未能从文件读取数据：%s\n', relPath);
            continue;
        end

        % 多声道整形（假设交织）
        if numChannels > 1
            n = numel(x) - mod(numel(x), numChannels);
            if n == 0
                fprintf('[Warn] 样本数不足以整形为 %d 声道：%s\n', numChannels, relPath);
                continue;
            end
            x = x(1:n);
            x = reshape(x, numChannels, []).';  % N x C
        end

        % 输出路径：保持相对层级到 outDir
        [subFolder, baseName, ~] = fileparts(relPath);
        outSubDir = fullfile(outDir, subFolder);
        if ~isempty(outSubDir) && ~isfolder(outSubDir)
            mkdir(outSubDir);
        end
        outPath = fullfile(outSubDir, [baseName '.wav']);

        % 写出 24bit wav（double 会量化到 24bit）
        xw = max(min(x, 1), -1); % 保守裁剪
        audiowrite(outPath, xw, fs, 'BitsPerSample', 24);
        fprintf('[OK] %s  ->  %s  (fs=%d, ch=%d)\n', relPath, erase(outPath, [outDir filesep]), fs, size(xw, 2));

        % 绘图验证
        if enablePlot
            figure('Name', baseName);
            % 仅绘制第1个声道的前5000个点，避免卡顿
            N_plot = min(5000, size(xw, 2));
            t = (0:N_plot-1) / fs;
            plot(t, xw(1:N_plot));
            grid on; ylim([-1.1 1.1]);
            xlabel('Time (s)'); ylabel('Amplitude');
            title(sprintf('Waveform: %s (First %d samples)', baseName, N_plot), 'Interpreter', 'none');
            drawnow;
        end
    catch ME
        fprintf('[Error] 转换失败：%s\n  原因：%s\n', relPath, ME.message);
    end
end

end

function tf = looks_like_coeff_file(filePath)
% 在文件前 2KB 搜索 ASCII 文本 "Coeffs"（不区分大小写）
% 若出现则认为是系数文件，直接跳过。

try
    fid = fopen(filePath, 'rb');
    if fid < 0
        tf = false; return;
    end
    cleaner = onCleanup(@() fclose(fid));
    headerLen = 2048;
    u8 = fread(fid, headerLen, 'uint8=>uint8');
    if isempty(u8)
        tf = false; return;
    end
    % 尝试当作ASCII文本查看
    ch = lower(char(u8(:).'));
    tf = contains(ch, 'coeffs');
catch
    tf = false;
end
end

function x = read_q1_23_file(filePath)
% 根据文件大小与数据特征尝试两种读取方式：
% 1) 24位打包（3字节大端）
% 2) 32位整型（4字节大端），自适应缩放

info = dir(filePath);
if isempty(info) || info.bytes == 0
    x = [];
    return;
end
len = info.bytes;

% 24-bit 打包优先判断 (只要是3的倍数，鉴于用户描述，优先当作24-bit)
if mod(len, 3) == 0
    x = read_q1_23_packed24(filePath);
    return;
end

% 32-bit 读取并自适应缩放
x = read_q1_23_int32_auto(filePath);

% 如果异常（大量越界），再尝试 24-bit 打包作为兜底
if isempty(x) || mean(abs(x) <= 1.1) < 0.95
    if mod(len, 3) == 0
        x2 = read_q1_23_packed24(filePath);
        if ~isempty(x2)
            x = x2;
        end
    end
end
end

function x = read_q1_23_packed24(filePath)
% 读取 24位打包大端（每样本3字节）并转换为 [-1, 1] double
try
    fid = fopen(filePath, 'rb');
    if fid < 0, x = []; return; end
    cleaner = onCleanup(@() fclose(fid));
    u8 = fread(fid, inf, 'uint8=>uint8');
    n = floor(numel(u8) / 3);
    if n == 0, x = []; return; end
    u8 = u8(1:3*n);
    U = reshape(u8, 3, n);
    
    % 大端序：U(1,:)为高位, U(3,:)为低位
    v = bitshift(uint32(U(1,:)), 16) + ...
        bitshift(uint32(U(2,:)), 8) + ...
        uint32(U(3,:));
        
    signBit = bitshift(uint32(1), 23);
    negMask = bitand(v, signBit) ~= 0;
    
    vs = int32(v);
    % 符号扩展: 24bit -> 32bit int
    if any(negMask)
        vs(negMask) = vs(negMask) - int32(16777216); % 2^24
    end
    
    x = double(vs) / 2^23;
catch
    x = [];
end
end

function x = read_q1_23_int32_auto(filePath)
% 读取 int32 大端并自动判断缩放（优先Q1.23，若过界严重尝试右移8位或按Q1.31）
try
    fid = fopen(filePath, 'rb', 'ieee-be');
    if fid < 0, x = []; return; end
    cleaner = onCleanup(@() fclose(fid));
    s32 = fread(fid, inf, 'int32=>int32');
    if isempty(s32), x = []; return; end

    cand = cell(3,1);
    score = zeros(3,1);

    % 方案A：直接按 Q1.23
    xa = double(s32) / 2^23;
    score(1) = quality_score(xa);
    cand{1} = xa;

    % 方案B：右移8位（若高8位非符号扩展）
    s32b = bitsra(s32, 8);
    xb = double(s32b) / 2^23;
    score(2) = quality_score(xb);
    cand{2} = xb;

    % 方案C：按 Q1.31
    xc = double(s32) / 2^31;
    score(3) = quality_score(xc);
    cand{3} = xc;

    [~, idx] = max(score);
    x = cand{idx};
catch
    x = [];
end
end

function s = quality_score(x)
% 质量评分：
% - 边界内占比（|x|<=1.05）
% - 动态范围（标准差）
inside = mean(abs(x) <= 1.05);
sdev = std(x);
% 避免死零，提升边界内且有一定动态的候选
s = inside + 0.1 * min(sdev/0.1, 1); % sdev>0.1 加分饱和
end
