function [y,e,Wgt] = FXLMS(X,d,FilterParams)
    % FXLMS 实现了基于 Filtered-x LMS 算法的自适应噪声控制
    % 输入参数:
    %   X - 输入信号矩阵，每一行是一个时间步的输入信号
    %   d - 期望信号（通常是误差信号）
    %   FilterParams - 包含滤波器参数的结构体，包括以下字段：
    %       Length - 滤波器长度
    %       StepSizeConst - 步长因子
    %       SecondaryPath - 次级路径的真实模型
    %       SecondaryPathEst - 次级路径的估计模型
    % 输出参数:
    %   y - 输出信号
    %   e - 误差信号
    %   Wgt - 每个时间步的权重矩阵

    % 提取滤波器参数
    L = FilterParams.Length; % 滤波器长度
    stepSize = FilterParams.StepSizeConst; % 步长因子
    secPath = FilterParams.SecondaryPath; % 次级路径的真实模型
    secPathEst = FilterParams.SecondaryPathEst; % 次级路径的估计模型

    Nstr = size(X,1);
    Xrev = zeros(length(secPathEst),1);
    filtXrev = zeros(L,1);
    Y = zeros(length(secPath),1);
    W = zeros(L,1);
    Wgt = zeros(L,Nstr);
    y = zeros(1,Nstr);
    e = zeros(1,Nstr);
    
    for i = 1:Nstr
        Xrev = [X(i) ; Xrev(1:end-1)];
        y(i) = FIR(W,Xrev); % 权重和原本的x 
        Y = [y(i);Y(1:end-1)];
        e(i) = d(i) - secPath * Y; % 
        filtX = secPathEst * Xrev; % filtered-x
        filtXrev = [filtX ; filtXrev(1:end-1)];
        W = W + stepSize.*filtX'*e(i);
        Wgt(:,i) = W;
    end
end