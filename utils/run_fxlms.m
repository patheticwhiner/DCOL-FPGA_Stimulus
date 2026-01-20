function [t,d,y_s,e,W_hist,w,params_out] = run_fxlms(params)
% RUN_FXLMS  Entry point for FxLMS simulation
% Refactored to use the Generic ANC Simulator (run_anc_sim) with the FxLMS strategy.
%
% This function preserves the interface for the GUI (fxlms_gui.m).

    % --- 1. Ensure Legacy Parameters exist ---
    if ~isfield(params, 'Lw'), params.Lw = 512; end
    if ~isfield(params, 'mu'), params.mu = 5e-4; end

    % --- 2. Inject FxLMS Strategy ---
    % Only set if not already provided (allows this function to be used as a config wrapper too)
    if ~isfield(params, 'createAlgFcn')
        % Define how to create the FxLMS algorithm instance
        % The runner calls this with (S_est, params)
        params.createAlgFcn = @(S_est, p) alg_fxlms(p.Lw, p.mu, S_est);
    end

    % --- 3. Delegate to Generic Simulator ---
    [t,d,y_s,e,W_hist,w,params_out] = run_anc_sim(params);

end
