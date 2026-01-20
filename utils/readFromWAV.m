function [y, fs] = readFromWAV(filename)
% readFromWAV  读取 WAV 文件，返回归一化的单通道音频和采样率
% 用法： [y, fs] = readFromWAV(filename)
% - y: 列向量，归一化（最大幅值为1）
% - fs: 采样率
% - filename: 支持绝对或相对路径

if ~exist(filename, 'file')
    error('文件不存在: %s', filename);
end

[y, fs] = audioread(filename);
if size(y,2) > 1
    y = y(:,1); % 默认只取第一通道
end

y = y(:); % 保证为列向量
if max(abs(y)) > 0
    y = y / max(abs(y)); % 归一化到[-1,1]
end

end
