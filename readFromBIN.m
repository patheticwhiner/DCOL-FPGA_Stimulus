% 读取二进制文件中的 24-bit 样本（每 3 字节为 1 个 sample），并将其解释为有符号 Q1.23，输出浮点数组 mic_float
clear; close all; clc;

% 修改为你的 .bin 文件路径
filename = 'sine_0.1_1kHzQ1_23.bin';

fid = fopen(filename, 'rb');
if fid == -1
    error('无法打开文件：%s', filename);
end

raw = fread(fid, Inf, 'uint8=>uint8');
fclose(fid);

nbytes = numel(raw);
if nbytes == 0
    error('文件为空或读取失败：%s', filename);
end

nsamples = floor(nbytes / 3);
if nsamples * 3 ~= nbytes
    fprintf('注意：文件字节数 %d 不是 3 的整数倍，将丢弃尾部 %d 字节。\n', nbytes, nbytes - nsamples*3);
    raw = raw(1:nsamples*3);
end

% 将数据按每3字节一列排列（每列一个 sample，顺序为 [b1; b2; b3]）
bytes = reshape(raw, 3, []);

% 假定文件中每个样本以大端字节序存储：b1 (MSB), b2, b3 (LSB)
vals = uint32(bytes(1,:)) * 65536 + uint32(bytes(2,:)) * 256 + uint32(bytes(3,:));

% 保证仅使用最低 24 位
vals = bitand(vals, hex2dec('FFFFFF'));

% 转换为有符号整数（24-bit 两补数）并归一化为 Q1.23
signed = double(vals);
neg_idx = vals >= 2^23;
signed(neg_idx) = signed(neg_idx) - 2^24;
mic_float = signed / 2^23;

% 诊断输出
fprintf('读取文件：%s，字节 %d，样本 %d。\n', filename, nbytes, nsamples);
fprintf('mic_float 范围: min=%g, max=%g\n', min(mic_float), max(mic_float));

% 打印前若干样本用于检查
preview = min(16, nsamples);
fprintf('前 %d 个样本（index: raw_hex -> float）：\n', preview);
for k = 1:preview
    b = bytes(:,k)';
    hexstr = sprintf('%02X%02X%02X', b(1), b(2), b(3));
    fprintf('  [%4d] 0x%s -> %g\n', k, hexstr, mic_float(k));
end

% 可选：保存为 MAT 文件，方便后续分析（取消注释以启用）
% save('mic_float_from_bin.mat', 'mic_float');

fprintf('完成：变量 mic_float 已在工作区。\n');
