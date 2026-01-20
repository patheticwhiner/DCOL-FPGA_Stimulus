clear; close all; clc;

%% 1. 仿真参数设置
T = 48000;              % 仿真时长 (采样点数)
fs = 48000;              % 采样率
mu = 1;             % 步长 (需根据信号功率调整)
FilterLen = 8;        % 自适应滤波器 W(z) 的长度

%% 2. 定义路径 (关键：P的延时要大于S，保证因果性)
D = read_q123_mem('D.mem')';
X = read_q123_mem('X.mem')';
S_impulse = read_q123_mem('secpath.mem')';
% S_impulse =   [ 0         0   -0.0809   -0.1932    0.0054];
% w_impulse =   [ 0         0    0.4389   -0.2628   -0.1272];
% P_impulse =   [ 0         0         0         0   -0.0355   -0.0635    0.0634    0.0231   -0.0007];


% Secondary Path S(z): 延时较短，模拟扬声器离误差麦克风近
% S_impulse = [zeros(1, 2), 0.2*randn(1,3)];

% Secondary Path Estimate Sh(z): 这里假设完美估计
Sh_impulse = S_impulse;

w_impulse =      [   0         0    0.0944    0.2910];
% w_impulse = [zeros(1, 2), 0.2*randn(1,2)];

% Primary Path P(z): 增加纯延时，模拟参考麦克风离得远
P_impulse = conv(w_impulse, S_impulse);

% 检查路径长度
len_P = length(P_impulse);
len_S = length(S_impulse);

%% 3. 生成噪声源
% 宽带白噪声
% X = 0.1*randn(1, T);

%% 4. 预计算主路径产生的干扰 (Primary Noise at Error Mic)
% D(n) = X(n) * P(z)
D = filter(P_impulse, 1, X);

%% 5. FxLMS 算法主循环
% 初始化
W = zeros(1, FilterLen);    % 自适应滤波器系数
X_buffer = zeros(1, FilterLen);     %用于W卷积的buffer
Ref_filtered_buffer = zeros(1, FilterLen); % 用于更新W的Filtered-X buffer

% 模拟次级路径传播所需的 Buffer (S(z)是FIR)
Y_out_buffer = zeros(1, len_S);

% 模拟 Sh(z) 滤波所需的 Buffer
X_Sh_buffer = zeros(1, length(Sh_impulse));

Error_Signal = zeros(1, T);
W_history = zeros(FilterLen, T); % 记录权重变化

fprintf('Simulation running...\n');

for n = 1 : T

    % --- Step 1: 产生反噪声控制信号 y(n) ---
    % 更新输入 buffer
    current_x = X(n);
    X_buffer = [current_x, X_buffer(1:end-1)];

    % 计算控制器输出 y(n) = W^T * X_vec
    y_n = sum(W .* X_buffer);

    % --- Step 2: 模拟次级路径物理传播 y'(n) = y(n) * S(z) ---
    Y_out_buffer = [y_n, Y_out_buffer(1:end-1)];
    y_prime = sum(Y_out_buffer .* S_impulse); % 这是实际抵达人耳的抗噪声

    % --- Step 3: 计算误差 e(n) = d(n) - y'(n) ---
    % 注意：ANC中通常定义 e = d + y' (声波叠加)，但为了算法推导常写成 d - y'
    % 这里假设 y_prime 是为了抵消 d，即理想情况 y_prime = -d
    % 物理上是叠加: e(n) = D(n) + y_prime.
    % 这意味着 W 最终会收敛到负值。
    e_n = D(n) + y_prime;
    Error_Signal(n) = e_n;

    % --- Step 4: 生成 Filtered-x 信号 (LMS 更新用) ---
    % x'(n) = x(n) * Sh(z)
    X_Sh_buffer = [current_x, X_Sh_buffer(1:end-1)];
    x_filtered = sum(X_Sh_buffer .* Sh_impulse);

    % 更新用于权重更新的 buffer
    Ref_filtered_buffer = [x_filtered, Ref_filtered_buffer(1:end-1)];

    % --- Step 5: 权重更新 (LMS) ---
    % W(n+1) = W(n) - mu * e(n) * x'(n)
    % 注意符号：如果是 e = d + y'，为了最小化 e^2，梯度方向导致更新为 - mu * e * x'
    W = W - mu * e_n * Ref_filtered_buffer;

    % 记录
    W_history(:, n) = W';
end

%% 6. 结果可视化
figure;

subplot(2,2,1);
plot(P_impulse); hold on; plot(S_impulse, 'r');
legend('Primary Path P(z)', 'Secondary Path S(z)');
title('Acoustic Paths (Impulse Response)');
grid on;

subplot(2,2,2);
plot(Error_Signal.^2);
title('Squared Error Curve (Learning Curve)');
xlabel('Iteration'); ylabel('e^2(n)');
grid on;
ylim([0 max(D.^2)*1.2]);

subplot(2,2,3);
% 比较开启 ANC 前后的频谱
[pxx_off, f] = pwelch(D(T/2:end), 512, 256, 512, fs);
[pxx_on, ~]  = pwelch(Error_Signal(T/2:end), 512, 256, 512, fs);
plot(f, 10*log10(pxx_off), 'b', 'LineWidth', 1.5); hold on;
plot(f, 10*log10(pxx_on), 'r', 'LineWidth', 1.5);
legend('ANC OFF', 'ANC ON');
title('Power Spectral Density');
xlabel('Frequency (Hz)'); ylabel('Power (dB)');
grid on;

subplot(2,2,4);
% 验证最优解逼近: Ideal W = -P/S
[H_opt, w_freq] = freqz(P_impulse, 1, 512);
[H_sec, ~] = freqz(S_impulse, 1, 512);
H_ideal = -H_opt ./ H_sec; % 理论最优频响

[H_sim, ~] = freqz(W, 1, 512); % 仿真最终得到的W
plot(w_freq/pi*fs/2, 20*log10(abs(H_ideal)), 'k--', 'LineWidth', 2); hold on;
plot(w_freq/pi*fs/2, 20*log10(abs(H_sim)), 'g', 'LineWidth', 1.5);
legend('Ideal Wiener Solution (-P/S)', 'FxLMS Converged W');
title('Filter Response Comparison');
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
grid on;

fprintf('Simulation Finished.\n');

figure; subplot(2,1,1);
plot(w_impulse); hold on; plot(W);
subplot(2,1,2); plot(D); hold on; plot(Error_Signal);

% 假设已加载 demo.m 的所有变量
fixed_w = -[8.249282836914066e-05, -0.000529408454895502, 0.09569537633961792, 0.288193702697754, 0.008217811584472666, -0.03608500957489901, 0.00220763683319092, 0.003302097320555664];
FilterLen = length(fixed_w);
X_buffer = zeros(1, FilterLen);
Y_out_buffer = zeros(1, len_S);
Error_Signal_fixed = zeros(1, T);

for n = 1 : T
    current_x = X(n);
    X_buffer = [current_x, X_buffer(1:end-1)];
    y_n = sum(fixed_w .* X_buffer);
    Y_out_buffer = [y_n, Y_out_buffer(1:end-1)];
    y_prime = sum(Y_out_buffer .* S_impulse);
    e_n = D(n) + y_prime;
    Error_Signal_fixed(n) = e_n;
end

% 可视化
figure;
subplot(2,2,1);
plot(D); hold on;
D1 = filter(conv(S_impulse,fixed_w),1,X);
plot(D1,'--');
plot(D+D1);
title('Fixed Filter Squared Error Curve');
xlabel('Iteration'); ylabel('e^2(n)');
grid on;

subplot(2,2,2);
[pxx_off, f] = pwelch(D(T/2:end), 512, 256, 512, fs);
[pxx_on, ~]  = pwelch(Error_Signal_fixed(T/2:end), 512, 256, 512, fs);
plot(f, 10*log10(pxx_off), 'b', 'LineWidth', 1.5); hold on;
plot(f, 10*log10(pxx_on), 'r', 'LineWidth', 1.5);
legend('ANC OFF', 'Fixed Filter ON');
title('Power Spectral Density (Fixed Filter)');
xlabel('Frequency (Hz)'); ylabel('Power (dB)');
grid on; ylim([-200,-80]);

subplot(2,2,3);
plot(D); hold on;
D2 = filter(conv(S_impulse,w_impulse),1,X);
plot(D2,'--');
plot(D-D2);
title('Fixed Filter Squared Error Curve');
xlabel('Iteration'); ylabel('e^2(n)');
grid on;
subplot(2,2,4);
[pxx_off, f] = pwelch(D(T/2:end), 512, 256, 512, fs);
[pxx_on, ~]  = pwelch(Error_Signal(T/2:end), 512, 256, 512, fs);
plot(f, 10*log10(pxx_off), 'b', 'LineWidth', 1.5); hold on;
plot(f, 10*log10(pxx_on), 'r', 'LineWidth', 1.5);
legend('ANC OFF', 'Fixed Filter ON');
title('Power Spectral Density (Fixed Filter)');
xlabel('Frequency (Hz)'); ylabel('Power (dB)');
grid on; ylim([-200,-80]);

function data = read_q123_mem(filename)
% 读取 Q1.23 有符号格式的 .mem 文件，返回浮点数组
fid = fopen(filename, 'r');
if fid < 0
    error('无法打开文件: %s', filename);
end

lines = {};
while ~feof(fid)
    line = strtrim(fgetl(fid));
    if isempty(line) || line(1) == ';' || line(1) == '@'
        continue;
    end
    % 只保留第一个逗号或空格前的内容
    line = regexp(line, '^[^, ;]*', 'match', 'once');
    if isempty(line)
        continue;
    end
    lines{end+1} = line; %#ok<AGROW>
end
fclose(fid);

N = numel(lines);
data = zeros(N,1);

for i = 1:N
    str = lines{i};
    % 允许无0x前缀的16进制
    if all(isstrprop(str, 'xdigit')) && length(str)==6
        val = hex2dec(str);
    elseif contains(str, 'x') || contains(str, 'X')
        val = hex2dec(strrep(lower(str), '0x', ''));
    else
        val = str2double(str);
    end
    if isnan(val)
        data(i) = NaN;
        continue;
    end
    % Q1.23: 24位有符号
    if val >= 2^23
        val = val - 2^24;
    end
    data(i) = val / 2^23;
end
end