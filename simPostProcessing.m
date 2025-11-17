close all; clc;

option = out.option.signals.values(1);
data = out.in.signals.values(:);
w = out.w.signals.values(end,:);
nameTag = ['Opfilter',num2str(option),'.mat'];
save(nameTag,'data','w');

[H,f] = freqz(w,1, 1024, fs);
figure;
subplot(2,1,1);
plot(f,20*log10(abs(H))); grid on;
subplot(2,1,2);
plot(f,angle(H)); grid on;

%% 预测固定滤波器降噪效果
in = out.in.signals.values(:);
t = (1:length(in))/fs;
out_predict = filter(P,1,in) - filter(conv(w,S),1,in);

fprintf('正在启动 Signal Analyzer 并导入信号...\n');
signalAnalyzer(in, out_predict, ...
    'SampleRate', fs);
fprintf('Signal Analyzer 已成功启动。\n');
fprintf('您现在可以在APP中查看时域波形和功率谱。\n');
