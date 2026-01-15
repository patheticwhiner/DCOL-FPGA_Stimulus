function alg = alg_fxnlms(Lw, mu, S_est)
% ALG_FXNLMS Strategies for Normalized FxLMS Algorithm
% Inputs:
%   Lw    : Filter length
%   mu    : Step size (normalized, typically 0.1 to 1.0)
%   S_est : Secondary path estimate vector

    S_est = S_est(:);
    len_S = length(S_est);

    alg.name = 'FxNLMS';
    alg.Lw = Lw;
    alg.initFcn = @init_state;
    alg.stepFcn = @step_algo;

    % Small epsilon to prevent division by zero
    epsilon = 1e-6;

    function state = init_state()
        state.fx_buf = zeros(Lw, 1);
    end

    function [w_next, state_next] = step_algo(w, x_buf, e, state)
        % 1. Filter reference x(n) through S_est
        x_vec_S = x_buf(1:len_S);
        fx_n = S_est' * x_vec_S;

        % 2. Update filtered-x buffer
        % fx_buf contains [fx(n); fx(n-1); ... ; fx(n-Lw+1)]
        fx_buf_new = [fx_n; state.fx_buf(1:Lw-1)];

        % 3. Calculate power of filtered-x vector
        pwr = fx_buf_new' * fx_buf_new;

        % 4. NLMS Update
        % w(n+1) = w(n) + (mu / (pwr + epsilon)) * e(n) * fx(n)
        step = mu / (pwr + epsilon);
        w_next = w + step * e * fx_buf_new;

        state_next.fx_buf = fx_buf_new;
    end
end
