%% simWorkSpaceConfig.m
% 作用：
%   - 为 Simulink 模型准备工作空间变量（参考路径 S、主路径 P、噪声源 data1/data2 等）；
%   - 同时给出简单的时域/频域可视化，方便检查信号是否合理。
% 使用方式：
%   - 在 MATLAB 命令行中运行本脚本，随后在 Simulink 模型中直接使用同名变量即可。

clear; close all; clc;
fprintf('================ simWorkSpaceConfig =================\n');

%% 模型初始化：加载二级路径/一级路径识别结果
stepsize = 0.00010;  % LMS 步长，可根据模型需要手动调整

fprintf('加载二级路径模型数据 (secpath) ...\n');
load('../data/LMS_SYSID2025-11-16_secpath.mat');   % 期望变量 s 包含 w、fs 等
S = s.w';                                           % 二级路径脉冲响应（转置为行向量）

fprintf('加载一级路径模型数据 (primpath) ...\n');
load('../data/LMS_SYSID2025-11-17_primpath.mat');  % 同样期望变量 s
P = s.w';                                           % 一级路径脉冲响应
fs = s.fs;                                          % 采样频率（假定两次识别的 fs 相同）
fprintf('模型采样频率 fs = %.1f Hz\n', fs);

%% 噪声信号构造：随机噪声 + 宽带录音
% 这里构造两个噪声源：
%   data1：经 bandpass 滤波的白噪声，频带可以调整；
%   data2：从文件读取的预先生成的噪声片段。
fprintf('开始构造噪声信号 ...\n');

N = fs*10;                 % data1 信号长度：10 秒
t = (0:N-1)'/fs;           % data1 对应的时间轴

% 信号1的频带：60~2000 Hz，可根据实际控制/主动噪声应用修改
f_low1 = 60;
f_high1 = 2000;
fprintf('  data1 目标频带: [%d, %d] Hz\n', f_low1, f_high1);
b1 = fir1(1024, [f_low1 f_high1]/(fs/2), 'bandpass');

% 信号2的频带（此处只用于初始设计，实际 data2 使用文件中的噪声）
f_low2 = 1200;
f_high2 = 2000;
fprintf('  data2 设计频带(未直接使用): [%d, %d] Hz\n', f_low2, f_high2);
b2 = fir1(1024, [f_low2 f_high2]/(fs/2), 'bandpass'); %#ok<NASGU>

% 生成白噪声并带通滤波，得到 data1
noise1 = randn(N,1);
noise2 = randn(N,1); %#ok<NASGU>
f_noise1 = filter(b1, 1, noise1);

% 从音频文件中读取噪声，作为 data2
fprintf('  从文件读取噪声: WN60T2kHz_Fs48kHz_1Worder_20200730.wav ...\n');
f_noise2 = audioread('../data/WN60T2kHz_Fs48kHz_1Worder_20200730.wav');

% 截取前 20 秒（如文件更短会自动截断到文件长度）
Ns2 = min(length(f_noise2), 20*fs);
f_noise2 = f_noise2(1:Ns2);
t2 = (0:Ns2-1)'/fs;
fprintf('  data1 长度 = %.2f s, data2 长度 = %.2f s\n', t(end), t2(end));

%% 信号初始化：按 Simulink 常用结构体格式组织
% data1 / data2 结构体字段说明：
%   - .time            : 时间向量，留空则 Simulink 使用自变量时间；
%   - .signals.values  : 实际信号数据（列向量）；
%   - .signals.dimensions : 信号维度，这里为标量信号 -> 1。

data1.time = [];
data1.signals.values = f_noise1;
data1.signals.dimensions = 1;

data2.time = [];
data2.signals.values = f_noise2;
data2.signals.dimensions = 1;

fprintf('已在工作区创建变量: S, P, fs, data1, data2。\n');

%% 绘图：data1 / data2 的时域 和 频域 预览
fprintf('绘制 data1 / data2 的时域与频域图像 ...\n');

figure('Name', 'data1');
subplot(2,1,1);
plot(t, f_noise1);
title('data1 - 时域');
xlabel('时间 (s)');
ylabel('幅值');
grid on;

subplot(2,1,2);
N_fft = 4096;
f = (0:N_fft/2-1)*fs/N_fft;
Y = fft(f_noise1, N_fft);
P2 = abs(Y/N_fft);
P1 = P2(1:N_fft/2);
P1(2:end-1) = 2*P1(2:end-1);
plot(f, 20*log10(P1));
title('data1 - 频域');
xlabel('频率 (Hz)');
ylabel('幅值 (dB)');
grid on;

figure('Name', 'data2');
subplot(2,1,1);
plot(t2, f_noise2);
title('data2 - 时域');
xlabel('时间 (s)');
ylabel('幅值');
grid on;

subplot(2,1,2);
N_fft = 4096;
f = (0:N_fft/2-1)*fs/N_fft;
Y = fft(f_noise2, N_fft);
P2 = abs(Y/N_fft);
P1 = P2(1:N_fft/2);
P1(2:end-1) = 2*P1(2:end-1);
plot(f, 20*log10(P1));
title('data2 - 频域');
xlabel('频率 (Hz)');
ylabel('幅值 (dB)');
grid on;

fprintf('simWorkSpaceConfig 运行结束，可以在 Simulink 中使用上述变量。\n');
