function alg = alg_imc_fxlms(Lw, mu, S_est)
% ALG_IMC_FXLMS Strategies for IMC-FxLMS Algorithm (Internal Model Control)
%
% This algorithm synthesizes the reference signal x(n) using an internal
% model of the secondary path, making it suitable for Feedback ANC where
% no external reference sensor is available.
%
% Inputs:
%   Lw    : Filter length (weights)
%   mu    : Step size
%   S_est : Secondary path estimate vector
%
% Returns a structure with function handles for initialization, step updates,
% and reference signal generation.

    % Ensure S_est is a column vector and store it
    S_est = S_est(:);
    len_S = length(S_est);

    alg.name = 'IMC-FxLMS';
    alg.Lw = Lw;

    alg.initFcn = @init_state;
    alg.stepFcn = @step_algo;
    alg.getRefFcn = @get_reference; % Interface for internal reference generation

    % --- Nested Functions ---

    function state = init_state()
        % Initialize algorithm state variables
        state.fx_buf = zeros(Lw, 1);       % Buffer for filtered reference signal (x')

        % Buffer for synthesizing reference (needs control signal y history)
        % Length matches S_est length for convolution
        state.y_buf = zeros(len_S, 1);

        % The synthesized reference for the *next* step (ref(n))
        % Initially 0 (since y(-1) etc are 0)
        state.d_hat_next = 0;
    end

    function [x_ref, state] = get_reference(~, state)
        % For IMC, we ignore external reference x_ext (first arg)
        % Return the synthesized reference calculated in the previous step
        x_ref = state.d_hat_next;
    end

    function [w_next, state_next] = step_algo(w, x_buf, e, state, yn)
        % Inputs:
        %   w     : Current weights
        %   x_buf : Buffer of reference signals (x(n), x(n-1)...)
        %           Note: In IMC, this contains the synthesized references.
        %   e     : Error signal e(n)
        %   state : Current state
        %   yn    : Control output y(n) generated at this step

        % 1. Standard FxLMS Weight Update
        % -------------------------------
        % Filter the reference signal x(n) through secondary path estimate S_est
        x_vec_S = x_buf(1:len_S);
        fx_n = S_est' * x_vec_S; % Scalar output of S_est filter

        % Update the buffer of filtered reference signal (filtered-x)
        fx_buf_new = [fx_n; state.fx_buf(1:Lw-1)];

        % LMS Update: w(n+1) = w(n) + mu * e(n) * fx(n)
        w_next = w + mu * e * fx_buf_new;

        % 2. Reference Synthesis (Internal Model Control)
        % -------------------------------
        % We estimate the disturbance d(n) to use as reference x(n+1)
        % Model: e(n) = d(n) - y_real(n) (where y_real is y * S)
        % Est:   d_hat(n) = e(n) + y_est(n) (where y_est is y * S_est)

        % Update y buffer with current control output yn to calculate y_est
        y_buf_new = [yn; state.y_buf(1:len_S-1)];

        % Estimate secondary path output (ys_hat)
        ys_hat = S_est' * y_buf_new;

        % Synthesize disturbance (which becomes next reference)
        d_hat = e + ys_hat;

        % Store for next iteration's get_reference
        state_next.d_hat_next = d_hat;

        % Update other state
        state_next.fx_buf = fx_buf_new;
        state_next.y_buf = y_buf_new;
    end
end
