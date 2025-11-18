function timeNpsdAnalysis(y,y_hat,e,WDLEN,fs)
    % 1. 误差信号分析
    mse = mean(e.^2);  % 计算均方误差
    disp(['均方误差 (MSE): ', num2str(mse)]);
    % 2. 估计误差相对比率分析
    fprintf('估计误差相对比率：%.2f %%\r\n',norm(e)^2/norm(y)^2*100);
    figure;
    % 时域分析 - 上半部分
    subplot(2,1,1);
    plot(y, 'b', 'LineWidth', 1); hold on;
    plot(y_hat, 'r', 'LineWidth', 1);
    plot(e, 'g', 'LineWidth', 1);
    xlabel('样本点', 'FontSize', 12);
    ylabel('幅值', 'FontSize', 12);
    title('LMS算法时域误差信号', 'FontSize', 14);
    legend('传感信号','估计信号','估计误差');
    grid on;
    % 功率谱密度分析 - 下半部分
    subplot(2,1,2);
    noverlap = round(WDLEN * 0.5);  % 重叠率50%
    nfft = 2^nextpow2(WDLEN);  % FFT点数
    [pdy, ~] = pwelch(y, hamming(WDLEN), noverlap, nfft, fs);
    [pyh, ~] = pwelch(y_hat, hamming(WDLEN), noverlap, nfft, fs);
    [pe, f] = pwelch(e, hamming(WDLEN), noverlap, nfft, fs);
    plot(f, 10*log10(pdy), 'b', 'LineWidth', 1.5); hold on;
    plot(f, 10*log10(pyh), 'r', 'LineWidth', 1.5);
    plot(f, 10*log10(pe), 'g', 'LineWidth', 1.5);
    xlabel('频率 (Hz)', 'FontSize', 12);
    ylabel('功率谱密度 (dB/Hz)', 'FontSize', 12);
    title('信号功率谱密度对比', 'FontSize', 14);
    legend('传感信号PSD','估计信号PSD','估计误差PSD');
    xlim([0 5000]);
    grid on;
end