function alg = alg_fxlms(Lw, mu, S_est)
% ALG_FXLMS Strategies for FxLMS Algorithm
% Returns a structure with function handles for initialization and step updates.
%
% Inputs:
%   Lw    : Filter length (weights)
%   mu    : Step size
%   S_est : Secondary path estimate vector

    % Ensure S_est is a column vector
    S_est = S_est(:);
    len_S = length(S_est);

    alg.name = 'FxLMS';
    alg.Lw = Lw;

    % Define function handles
    alg.initFcn = @init_state;
    alg.stepFcn = @step_algo;

    % --- Nested Functions ---

    function state = init_state()
        % Initialize algorithm state variables
        state.fx_buf = zeros(Lw, 1); % Buffer for filtered reference signal
    end

    function [w_next, state_next] = step_algo(w, x_buf, e, state, ~)
        % x_buf: Reference signal buffer (current sample at index 1)
        % e    : Current error sample
        % state: Current state structure

        % 1. Filter the reference signal x(n) through secondary path estimate S_est
        % Requires x_buf to have enough history: x(n), x(n-1)...
        x_vec_S = x_buf(1:len_S);
        fx_n = S_est' * x_vec_S; % Scalar output of S_est filter

        % 2. Update the buffer of filtered reference signal (filtered-x)
        % fx_buf contains [fx(n); fx(n-1); ... ; fx(n-Lw+1)]
        fx_buf_new = [fx_n; state.fx_buf(1:Lw-1)];

        % 3. LMS Update: w(n+1) = w(n) + mu * e(n) * fx(n)
        w_next = w + mu * e * fx_buf_new;

        % 4. Return updated state
        state_next.fx_buf = fx_buf_new;
    end
end
