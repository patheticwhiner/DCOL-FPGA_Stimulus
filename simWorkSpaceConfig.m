clear; close all; clc;

%% 模型初始化
stepsize = 0.0010;
load('data/LMS_SYSID2025-11-16_secpath.mat');
S = s.w';
load('data/LMS_SYSID2025-11-17_primpath.mat');
P = s.w';
fs = s.fs;

%% 噪声信号
N = fs*10;
t = (0:N-1)'/fs;

% 信号1的频带
f_low1 = 60;
f_high1 = 2000;
b1 = fir1(1024, [f_low1 f_high1]/(fs/2), 'bandpass');
% 信号2的频带
f_low2 = 1200;
f_high2 = 2000;
b2 = fir1(1024, [f_low2 f_high2]/(fs/2), 'bandpass');

noise1 = randn(N,1);
noise2 = randn(N,1);
f_noise1 = filter(b1, 1, noise1);
f_noise2 = filter(b2, 1, noise2);

f_noise2 = audioread('data/WN60T2kHz_Fs48kHz_1Worder_20200730.wav');
f_noise2 = f_noise2(1:20*fs);
t2 = (1:length(f_noise2))/fs;

%% 信号初始化
data1.time = [];
data1.signals.values = f_noise1;
data1.signals.dimensions = 1;

data2.time = [];
data2.signals.values = f_noise2;
data2.signals.dimensions = 1;

%% 绘图
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
