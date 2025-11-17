
clear; close all; clc;

%% ======================== 数据读取与预处理 ========================
% 读取输入信号（激励：白噪声）和输出信号（测量：麦克风数据）
x = readFromBIN('data/whitenoise200-2kHz.bin')'; % 输入信号，Q1.23格式，已转浮点
y = readFromCSV('data/mic_data_20251117_213813.csv'); % 输出信号，浮点

% 剔除 NaN，保证数据有效性
x = x(~isnan(x));
y = y(~isnan(y));

% 对齐长度（取最短长度，开头对齐）
minLen = min(length(x), length(y));
x = x(1:minLen);
y = y(1:minLen);

Fs = 48000;              % 采样频率（Hz）
t = (0:length(x)-1)'/Fs; % 时间向量（秒）


%% ======================== 信号时域与频域分析 ========================
% 可选：试听信号
% sound([x, y], Fs);

window_length = 1024;                % Welch分析窗口长度
window = hamming(window_length);     % 汉明窗
noverlap = window_length/2;          % 重叠长度
nfft = max(2048, 2^nextpow2(window_length)); % FFT点数

figure;
subplot(2,2,1);
plot(t, x); grid on;
title('激励信号的幅值');
xlabel('时间（s）'); ylabel('幅值（V）');

subplot(2,2,2);
[px, f] = pwelch(x, window, noverlap, nfft, Fs);
plot(f,10*log10(px));
title('输入信号的功率谱密度');
xlabel('频率 (Hz)'); ylabel('功率谱密度 (dB/Hz)');
xlim([0 5000]); grid on;

subplot(2,2,3);
plot(t, y); grid on;
title('测量信号的幅值');
xlabel('时间（s）'); ylabel('幅值（Pa）');

subplot(2,2,4);
[py, f] = pwelch(y, window, noverlap, nfft, Fs);
plot(f,10*log10(py));
title('输出信号的功率谱密度');
xlabel('频率 (Hz)'); ylabel('功率谱密度 (dB/Hz)');
xlim([0 5000]); grid on;


%% ======================== 可选重采样 ========================
fs = Fs; % 保持原采样率
% 如需重采样，可取消注释：
% fs = 2^13;
% x = resample(x, fs, Fs);
% y = resample(y, fs, Fs);
% t = resample(t, fs, Fs);


%% ======================== 信号前处理 ========================
% 1. 截取稳态部分（如需截去前两秒，可在此处处理）
data_x = x;
data_y = y;

% 2. 去趋势处理 - 消除直流分量和线性趋势
data_x = detrend(data_x);
data_y = detrend(data_y);

% 3. 陷波滤波 - 滤除50Hz及其谐波
f_notch = [50, 100, 150]; % 需滤除的频率（Hz）
for i = 1:length(f_notch)
    wo = f_notch(i)/(fs/2);      % 归一化频率
    bw = wo/35;                  % 陷波器带宽，Q=35
    [b, a] = iirnotch(wo, bw);   % 设计陷波器
    data_y = filtfilt(b, a, data_y); % 双向滤波
end

% 4. 带通滤波（如需过滤不需要频段，可取消注释并调整参数）
% [b, a] = butter(2, [60 3000]/(fs/2), 'bandpass');
% data_x = filtfilt(b, a, double(data_x));
% data_y = filtfilt(b, a, double(data_y));


%% ======================== 1. 相干性分析 ========================
WDLEN = 2^13;                      % 窗口长度
window = hann(WDLEN);              % 汉宁窗
noverlap = round(WDLEN * 0.75);    % 重叠率75%
nfft = 2^nextpow2(WDLEN);          % FFT点数

% 计算相干性
[Cxy, f] = mscohere(data_x, data_y, window, noverlap, nfft, fs);

% 绘制相干性
figure;
plot(f, Cxy, 'b', 'LineWidth', 1.5);
axis([0 5000 0 1]);
xlabel('Frequency (Hz)', 'FontSize', 12);
ylabel('Coherence', 'FontSize', 12);
title('Magnitude-Squared Coherence', 'FontSize', 14);
grid on;


%% ======================== 2. LMS次级通路辨识 ========================
% LMS算法参数设置
mu = 8e-3;                % 步长因子，控制收敛速度和稳定性
filter_order = 2^10;      % 滤波器阶数
w = zeros(filter_order, 1); % 初始化滤波器权重
N = length(data_x);         % 数据长度
y_hat = zeros(N, 1);        % 估计输出
e = zeros(N, 1);            % 误差信号
x_segment = zeros(filter_order,1); % 输入信号段缓存

% LMS算法迭代
for n = filter_order:N
    x_segment = data_x(n:-1:n-filter_order+1);  % 输入信号段
    x_segment = x_segment(:);                   % 保证为列向量
    y_hat(n) = w' * x_segment;                  % 估计输出
    e(n) = data_y(n) - y_hat(n);                % 误差信号
    w = w + 2 * mu * e(n) * x_segment;          % 更新权重
end

% 绘制滤波器权重及其频率响应分析
figure;
subplot(2,1,1);
plot(w);
xlabel('滤波器系数索引', 'FontSize', 12);
ylabel('权重值', 'FontSize', 12);
title('LMS算法辨识的滤波器权重', 'FontSize', 14);
grid on; hold on;

subplot(2,1,2);
[H, f_response] = freqz(w, 1, 1024, fs);  % 计算频率响应
plot(f_response, 20*log10(abs(H)), 'LineWidth', 1.5);
xlabel('Frequency (Hz)', 'FontSize', 12);
ylabel('Magnitude (dB)', 'FontSize', 12);
title('辨识滤波器的频率响应', 'FontSize', 14);
grid on;

% 辨识结果的时域分析
timeNpsdAnalysis(data_y, y_hat, e, WDLEN, fs);


%% ======================== 3. 辨识结果的滤波时域分析 ========================
% （1）均方误差分析
xf = filter(w, 1, x);           % 用辨识模型滤波输入信号
err = y - xf;                   % 误差信号
WDLEN = 2^13;                   % 频谱分析窗口长度
timeNpsdAnalysis(y, xf, err, WDLEN, fs);

% （2）误差信号分析（用去趋势后的信号）
y_hhat = filter(w, 1, data_x);  % 用辨识模型滤波去趋势后的输入
ee = data_y - y_hhat;           % 误差信号
timeNpsdAnalysis(data_y, y_hhat, ee, WDLEN, fs);


%% ======================== 4. 互谱法与辨识模型对比分析 ========================
figure;
% 1. 通过互谱密度和自谱密度计算FRF
window = hann(WDLEN);
noverlap = round(WDLEN * 0.75);
nfft = 2^nextpow2(WDLEN);

% 计算互谱密度和自谱密度
[Pxx, f] = pwelch(data_x, window, noverlap, nfft, fs);      % 输入信号自谱密度
[Pxy, ~] = cpsd(data_x, data_y, window, noverlap, nfft, fs);% 输入输出互谱密度
[Pyy, ~] = pwelch(data_y, window, noverlap, nfft, fs);      % 输出信号自谱密度

% 计算FRF (H1估计和H2估计)
H1 = Pxy ./ Pxx;           % H1估计 - 输出噪声敏感
H2 = Pyy ./ conj(Pxy);     % H2估计 - 输入噪声敏感
H1_mag = abs(H1);
H1_phase = angle(H1);
H2_mag = abs(H2);
H2_phase = angle(H2);

% 2. 计算LMS辨识所得FIR模型的频率响应
[H_lms, f_lms] = freqz(w, 1, nfft, fs);
H_lms_mag = abs(H_lms);
H_lms_phase = angle(H_lms);

% 3. 幅度响应对比
subplot(3,1,1);
plot(f, 20*log10(H1_mag), 'b', 'LineWidth', 1.5); hold on;
plot(f, 20*log10(H2_mag), 'g', 'LineWidth', 1.5);
plot(f_lms, 20*log10(H_lms_mag), 'r', 'LineWidth', 1.5);
xlabel('频率 (Hz)', 'FontSize', 12);
ylabel('幅度 (dB)', 'FontSize', 12);
title('频率响应函数幅度对比', 'FontSize', 14);
legend('H1估计 (输出噪声敏感)', 'H2估计 (输入噪声敏感)', 'LMS辨识模型');
grid on;
xlim([0 1000]);

% 4. 相位响应对比
subplot(3,1,2);
plot(f, H1_phase*180/pi, 'b', 'LineWidth', 1.5); hold on;
plot(f, H2_phase*180/pi, 'g--', 'LineWidth', 1.5);
plot(f_lms, H_lms_phase*180/pi, 'r', 'LineWidth', 1.5);
xlabel('频率 (Hz)', 'FontSize', 12);
ylabel('相位 (度)', 'FontSize', 12);
title('频率响应函数相位对比', 'FontSize', 14);
legend('H1估计', 'H2估计', 'LMS辨识模型');
grid on;
xlim([0 1000]);

% 5. 相干性作为估计质量指标
subplot(3,1,3);
plot(f, Cxy, 'k', 'LineWidth', 1.5);
xlabel('频率 (Hz)', 'FontSize', 12);
ylabel('相干性', 'FontSize', 12);
title('相干性 - 频率响应估计质量指标', 'FontSize', 14);
grid on;
xlim([0 1000]);
ylim([0 1]);

% 6. 幅度差异分析
figure;
subplot(2,1,1);
mag_diff_H1_LMS = 20*log10(H1_mag) - 20*log10(H_lms_mag(1:length(H1_mag))); % H1与LMS差异
mag_diff_H2_LMS = 20*log10(H2_mag) - 20*log10(H_lms_mag(1:length(H2_mag))); % H2与LMS差异
plot(f, mag_diff_H1_LMS, 'b', 'LineWidth', 1.5); hold on;
plot(f, mag_diff_H2_LMS, 'g', 'LineWidth', 1.5);
xlabel('频率 (Hz)', 'FontSize', 12);
ylabel('幅度差异 (dB)', 'FontSize', 12);
title('互谱法与LMS辨识模型的幅度差异', 'FontSize', 14);
legend('H1估计与LMS差异', 'H2估计与LMS差异');
grid on;
xlim([0 5000]);

% 7. 高相干区域分析
subplot(2,1,2);
coherence_threshold = 0.8;  % 相干性阈值
good_coherence = (Cxy > coherence_threshold);
plot(f, Cxy, 'k', 'LineWidth', 1.5); hold on;
plot(f(good_coherence), Cxy(good_coherence), 'r.', 'MarkerSize', 8);
xlabel('频率 (Hz)', 'FontSize', 12);
ylabel('相干性', 'FontSize', 12);
title('高相干区域 - 估计更可靠的频段', 'FontSize', 14);
grid on;
xlim([0 5000]);
ylim([0 1]);


%% ======================== 保存辨识结果 ========================
current_time = datetime('now');
formatted_time = datestr(current_time, 'yyyy-mm-dd HH:MM:SS');
formatted_time = strrep(formatted_time, ':', '');
formatted_time = strrep(formatted_time, ' ', '_');
filename = ['data\LMS_SYSID', formatted_time];
s = struct('w', w, 'fs', fs, 'mu', mu, 'x', data_x, 'y', data_y); % 保存主要参数和信号
save(filename, 's');