function mic_data = readFromCSV(filename)
% readFromCSV - 从 CSV 文件读取第二列三字节 Q1.23 hex 字段并转换为浮点
%
% SYNTAX
%   mic_data = readFromCSV(filename)
%   mic_data = readFromCSV()  % 使用默认文件名
%
% INPUT
%   filename - 可选，CSV 文件路径（字符串）。若未提供，使用默认值 'mic_data_20251115_205337.csv'
%
% OUTPUT
%   mic_data - double 向量，Q1.23 转换后的浮点样本（NaN 表示解析失败或缺失）

if nargin < 1 || isempty(filename)
    fprintf('未提供文件名\n');
end

% 为避免 readtable 自动类型转换或编码错误，直接以原始单元格方式读取文件
% readcell 会保留原始单元格文本（包括前导 '0x' 等），更适合后续逐项解析
try
    C = readcell(filename, 'FileType', 'text');
catch
    % 退回到更兼容的 textscan 方式
    fid = fopen(filename, 'r');
    if fid == -1, error('无法打开文件：%s', filename); end
    hdr = fgetl(fid); %#ok<NASGU>
    data_scanned = textscan(fid, repmat('%s',1,2), 'Delimiter', ',', 'CollectOutput', true);
    fclose(fid);
    C = data_scanned{1};
end
if size(C,2) < 2
    error('CSV 文件列数不足，无法读取第二列。');
end
% 假定第一行为表头（如 README 所述），去掉首行以获得数据部分
if size(C,1) >= 2
    data_cells = C(2:end, :);
else
    data_cells = C;
end
% 取第二列并强制为 string，保留原始文本表示（例如 "0x000000"）
mic_hex = string(data_cells(:,2));

% 诊断：显示 mic_hex 的类型和前若干项，便于排查为何出现超长字段
fprintf('mic_hex 类型: %s, 大小: %s\n', class(mic_hex), mat2str(size(mic_hex)));
% 打印前 10 个原始项（带可见边界）
max_preview = min(10, size(mic_hex,1));
fprintf('前 %d 项原始 mic_hex 示例:\n', max_preview);
for k = 1:max_preview
    try
        raw = mic_hex(k, :);
        rs = string(raw);
    catch
        rs = "<无法读取>";
    end
    fprintf('  [%d] class=%s len=%d: "%s"\n', k, class(raw), strlength(string(rs)), char(rs));
end

n = numel(mic_hex);

% 强制把输入视为字符/字符串数组，按要求优先读取 '0x' 后紧接的最多 6 个 hex 字符；
% 若不存在 '0x'，则移除非 hex 字符并取最低 6 位（最后 6 个 hex 字符）。
mic_float = nan(n,1);
s_all = string(mic_hex(:));
for i = 1:n
    s = strtrim(s_all(i));
    if s == "" || ismissing(s)
        mic_float(i) = NaN;
        continue;
    end

    % 查找 '0x'（不区分大小写）并优先提取其后面的 hex 字符
    p = regexpi(s, '0x');
    if ~isempty(p)
        % 取第一个 '0x' 后面的字符序列，去掉所有非 hex 字符，再取前 6 个
        rest = extractAfter(s, p(1)+1); % 文本中 '0x' 后的部分
        rest_hex = regexprep(string(rest), '[^0-9A-Fa-f]', '');
        if strlength(rest_hex) == 0
            % 无法解析，留为 NaN
            mic_float(i) = NaN;
            continue;
        end
        hex6 = char(extractBetween(rest_hex, 1, min(6, strlength(rest_hex))));
        % 如果不足6位，左侧补零（确保代表相同数量级）
        if strlength(hex6) < 6
            hex6 = pad(hex6, 6, 'left', '0');
        end
    else
        % 无 '0x' 前缀：移除非 hex 字符，取最低（最后）6个 hex 字符
        cleaned = regexprep(string(s), '[^0-9A-Fa-f]', '');
        if strlength(cleaned) == 0
            mic_float(i) = NaN; continue;
        end
        if strlength(cleaned) > 6
            hex6 = char(extractBetween(cleaned, strlength(cleaned)-5, strlength(cleaned)));
        else
            hex6 = char(pad(cleaned, 6, 'left', '0'));
        end
    end

    % 将 hex 字符串转换为数值，按大端字节序解释为 24-bit
    % 规范化为大写 char，确保仅包含 6 个十六进制字符
    hex6 = char(upper(string(hex6)));
    if ~(ischar(hex6) && numel(hex6) == 6 && all(isstrprop(hex6, 'xdigit')))
        % 非法 hex 字符或长度不对，返回 NaN
        mic_float(i) = NaN; continue;
    end
    val = uint32(hex2dec(hex6));
    val = bitand(val, hex2dec('FFFFFF'));
    if val >= 2^23
        signed = double(val) - 2^24;
    else
        signed = double(val);
    end
    mic_float(i) = signed / 2^23;
end

% 将结果保存到常用变量名 mic_data，便于返回和后续脚本使用
mic_data = mic_float;

% 统计信息（忽略 NaN）
valid = ~isnan(mic_data);
if any(valid)
    non_zero_count = sum(mic_data(valid) ~= 0);
    negative_count = sum(mic_data(valid) < 0);
    positive_count = sum(mic_data(valid) > 0);
    first_non_zero = find(mic_data ~= 0, 1, 'first');
    first_negative = find(mic_data < 0, 1, 'first');
    fprintf('成功导入 %d 个数据点（含 NaN: %d）\n', numel(mic_data), sum(~valid));
    fprintf('数据范围: min=%g, max=%g\n', min(mic_data(valid)), max(mic_data(valid)));
    fprintf('非零数据点: %d (%.2f%%)\n', non_zero_count, 100*non_zero_count/sum(valid));
    fprintf('负数数据点: %d (%.2f%%)\n', negative_count, 100*negative_count/sum(valid));
    fprintf('正数数据点: %d (%.2f%%)\n', positive_count, 100*positive_count/sum(valid));
    if ~isempty(first_non_zero)
        fprintf('第一个非零数据位于索引: %d, 值: %g\n', first_non_zero, mic_data(first_non_zero));
    end
    if ~isempty(first_negative)
        fprintf('第一个负数位于索引: %d, 值: %g\n', first_negative, mic_data(first_negative));
    end
else
    fprintf('未找到有效数据（所有样本为 NaN）。\n');
end

% 绘图（对 NaN 自动省略）
figure('Name','mic_data (Q1.23 -> float)');
plot(mic_data);
title('mic\_data (Q1.23 -> float)')

end