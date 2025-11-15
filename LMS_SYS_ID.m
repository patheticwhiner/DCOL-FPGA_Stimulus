% clear; close all; clc;

%% 管道仿真数据
x = double(exported_signal)';
y = mic_data(1:480000);
Fs = 48000;

% [x, y, t, Fs] = DataManager(20);
dt = 1/Fs;
t = (1:length(y))*dt;

%% 信号时域与频域
% sound([data_x,data_y], fs);
window_length = 1024;
window = hamming(window_length);
noverlap = window_length/2;
nfft = max(2048, 2^nextpow2(window_length));

figure;
subplot(2,2,1);
plot(t, x); grid on;
title('激励信号的幅值'); % xlim([0,0.02]);
xlabel('时间（s）'); ylabel('幅值（V）');
subplot(2,2,2);
[px, f] = pwelch(x, window, noverlap, nfft, Fs);
plot(f,10*log10(px));
title('输入信号的功率谱密度');
xlabel('频率 (Hz)'); ylabel('功率谱密度 (dB/Hz)');
xlim([0 5000]); grid on; 
subplot(2,2,3);
plot(t,y); grid on;
title('测量信号的幅值'); % xlim([0,0.02]);
xlabel('时间（s）'); ylabel('幅值（Pa）');
subplot(2,2,4);
[py, f] = pwelch(y, window, noverlap, nfft, Fs);
plot(f,10*log10(py));
title('输出信号的功率谱密度');
xlabel('频率 (Hz)'); ylabel('功率谱密度 (dB/Hz)');
xlim([0 5000]); grid on;

%% 重采样
fs = Fs;
% fs = 2^13;
% x = resample(x, fs, Fs);
% y = resample(y, fs, Fs);
% t = resample(t, fs, Fs);

%% 前处理
% 1. 截取稳态部分(截去前两秒)
data_x = x;
data_y = y;
% 2. 去趋势处理 - 消除直流分量和线性趋势
data_x = detrend(data_x);
data_y = detrend(data_y);

% 3. 陷波滤波 - 滤除50Hz及谐波
f_notch = [50, 100, 150]; % 要滤除的频率
for i = 1:length(f_notch)
    wo = f_notch(i)/(fs/2);
    bw = wo/35; % 陷波器带宽, 35是品质因数Q, Q越大, 带宽越窄
    [b, a] = iirnotch(wo, bw);
    data_y = filtfilt(b, a, data_y);
end

% 4. 带通滤波 - 过滤掉不需要的频段(根据实际需求调整)
% [b, a] = butter(2, [60 3000]/(fs/2), 'bandpass');
% data_x = filtfilt(b, a, double(data_x));
% data_y = filtfilt(b, a, double(data_y));

%% 1 相干性分析
% 相干性分析
WDLEN = 2^13;  % 窗口长度
window = hann(WDLEN);
noverlap = round(WDLEN * 0.75);  % 重叠率75%
nfft = 2^nextpow2(WDLEN);  % FFT点数
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

%% 2 LMS次级通路辨识
% LMS算法参数设置
mu = 5e-5;  % 步长因子，控制收敛速度和稳定性
filter_order = 2^10;  % 滤波器阶数
w = zeros(filter_order, 1);  % 初始化滤波器权重
N = length(data_x);  % 数据长度
y_hat = zeros(N, 1);  % 估计输出
e = zeros(N, 1);  % 误差信号
x_segment = zeros(filter_order,1);

% LMS算法迭代
for n = filter_order:N
    x_segment = data_x(n:-1:n-filter_order+1);  % 输入信号段
    x_segment = x_segment(:);  % 确保 x_segment 是列向量
    y_hat(n) = w' * x_segment;  % 估计输出
    e(n) = data_y(n) - y_hat(n);  % 误差信号
    w = w + 2 * mu * e(n) * x_segment;  % 更新权重
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
timeNpsdAnalysis(data_y,y_hat,e,WDLEN,fs);

%% 3 辨识结果的滤波时域分析（1）
% 1.均方误差
xf = filter(w, 1, x);
err = y - xf;
WDLEN = 2^13; % 设置频谱分析的窗口长度
timeNpsdAnalysis(y,xf,err,WDLEN,fs);

%% 3 辨识结果的滤波时域分析（2）
% 1. 误差信号分析
y_hhat = filter(w,1,data_x);
ee = data_y-y_hhat;
timeNpsdAnalysis(data_y,y_hhat,ee,WDLEN,fs);

%% 4 测试与辨识的对标分析 - 互谱法计算FRF与辨识模型对比
figure;
% 1. 通过互谱密度和自谱密度计算FRF
% WDLEN = 2^13;  % 窗口长度
window = hann(WDLEN);
noverlap = round(WDLEN * 0.75);  % 重叠率75%
nfft = 2^nextpow2(WDLEN);  % FFT点数

% 计算互谱密度和自谱密度
[Pxx, f] = pwelch(data_x, window, noverlap, nfft, fs);  % 输入信号的自谱密度
[Pxy, ~] = cpsd(data_x, data_y, window, noverlap, nfft, fs);  % 输入输出的互谱密度
[Pyy, ~] = pwelch(data_y, window, noverlap, nfft, fs);  % 输出信号的自谱密度
% 计算FRF (H1估计和H2估计)
H1 = Pxy ./ Pxx;  % H1估计 - 适合输出噪声较大的情况
H2 = Pyy ./ conj(Pxy);  % H2估计 - 适合输入噪声较大的情况
H1_mag = abs(H1);
H1_phase = (angle(H1));
H2_mag = abs(H2);
H2_phase = (angle(H2));
% 2. 计算LMS辨识所得FIR模型的频率响应
[H_lms, f_lms] = freqz(w, 1, nfft, fs);
H_lms_mag = abs(H_lms);
H_lms_phase = (angle(H_lms));
% 3. 各种方法的幅度响应对比
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

% 6. 额外展示幅度差异分析
figure;
subplot(2,1,1);
% 计算H1和LMS之间的幅度差异
mag_diff_H1_LMS = 20*log10(H1_mag) - 20*log10(H_lms_mag(1:length(H1_mag)));
% 计算H2和LMS之间的幅度差异
mag_diff_H2_LMS = 20*log10(H2_mag) - 20*log10(H_lms_mag(1:length(H2_mag)));
plot(f, mag_diff_H1_LMS, 'b', 'LineWidth', 1.5); hold on;
plot(f, mag_diff_H2_LMS, 'g', 'LineWidth', 1.5);
xlabel('频率 (Hz)', 'FontSize', 12);
ylabel('幅度差异 (dB)', 'FontSize', 12);
title('互谱法与LMS辨识模型的幅度差异', 'FontSize', 14);
legend('H1估计与LMS差异', 'H2估计与LMS差异');
grid on;
xlim([0 5000]);
% 在相干性较好的频段内进行分析
subplot(2,1,2);
coherence_threshold = 0.8;  % 设置相干性阈值
good_coherence = (Cxy > coherence_threshold);
plot(f, Cxy, 'k', 'LineWidth', 1.5); hold on;
plot(f(good_coherence), Cxy(good_coherence), 'r.', 'MarkerSize', 8);
% yline(coherence_threshold, '--', ['阈值: ' num2str(coherence_threshold)], 'LineWidth', 1.5);
xlabel('频率 (Hz)', 'FontSize', 12);
ylabel('相干性', 'FontSize', 12);
title('高相干区域 - 估计更可靠的频段', 'FontSize', 14);
grid on;
xlim([0 5000]);
ylim([0 1]);

%% 绘制图像
figure;
t = t(1:length(x));
subplot(3,1,1); plot(t,x); xlim([0,0.005]);
subplot(3,1,2); plot(t,x); xlim([50/fs,0.005+50/fs]);
subplot(3,1,3); plot(t,y); xlim([0,0.005]);

%% 保存文件
current_time = datetime('now');
formatted_time = datestr(current_time, 'yyyy-mm-dd HH:MM:SS');
formatted_time = strrep(formatted_time,':','');
formatted_time = strrep(formatted_time,' ','_');
filename = ['LMS_SYSID',formatted_time];
s = struct('w',w ,'fs',fs, 'mu',mu, 'x',data_x, 'y',data_y);
save(filename, 's');