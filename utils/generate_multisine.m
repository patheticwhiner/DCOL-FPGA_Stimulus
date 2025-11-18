% generate_multisine.m
% Generate a 10-second multi-sine (non-harmonic components) at 48 kHz
% and export time,value columns to CSV: multisine_10s_48k.csv
%
% Usage: edit parameters below if desired, then run in MATLAB:
%   generate_multisine
%
% The script is standalone and uses writematrix (R2019a+). If your MATLAB
% version doesn't have writematrix, replace with csvwrite or dlmwrite.

% Parameters
Fs = 48000;        % sample rate (Hz)
T = 10;            % duration (s)
num_samples = Fs * T;

% Non-harmonic frequencies (Hz) - choose values that are not integer multiples
% Feel free to modify these frequencies or add/remove components
freqs = [437.3, 1234.5, 2789.2, 5921.7, 11000.1];
amps  = [0.9,   0.6,    0.45,   0.3,     0.2];   % linear amplitudes

% Optional: fix random seed for reproducible random phases
seed = 12345;
rng(seed);
phases = 2*pi*rand(1, numel(freqs));

% Time vector (column)
t = (0:(num_samples-1))' / Fs;

% Build signal
y = zeros(size(t));
for k = 1:numel(freqs)
    y = y + amps(k) * sin(2*pi*freqs(k)*t + phases(k));
end

% Normalize to avoid clipping (keep a small headroom)
mx = max(abs(y));
if mx > 0
    y = (y / mx) * 0.95;
end

% Export: time,value columns
out = [t, y];
filename = fullfile(pwd, 'multisine_10s_48k.csv');
try
    writematrix(out, filename);
    fprintf('Saved %d samples (%.1f s) to %s\n', numel(y), T, filename);
catch ME
    % Fallback for older MATLAB versions
    try
        csvwrite(filename, out);
        fprintf('Saved (csvwrite fallback) %d samples to %s\n', numel(y), filename);
    catch
        error('Failed to write CSV: %s', ME.message);
    end
end

% Quick plot preview (first 2000 samples to keep UI responsive)
figure('Name','Multisine Preview');
plot(t(1:min(end,2000)), y(1:min(end,2000)));
title('Multisine (first samples)');
xlabel('Time (s)'); ylabel('Amplitude');
grid on;

% end of script
