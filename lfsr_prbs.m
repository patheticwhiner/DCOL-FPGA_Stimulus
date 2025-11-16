function out = lfsr_prbs(order, seed, Nout, taps)
    % Robust Fibonacci-style LFSR (MSB-first) producing 0/1 sequence of length Nout
    % taps should be specified as polynomial degrees, e.g. [13 11] for x^13 + x^11 + 1
    if nargin<4, taps = []; end
    if seed == 0
        seed = 1; % avoid all-zero state
    end
    % sanitize taps: keep integers within [1,order]
    taps = unique(floor(taps));
    taps = taps(taps>=1 & taps<=order);
    if isempty(taps)
        % default primitive-ish taps for small orders (fallback)
        taps = max(1, order-1);
    end

    % Initialize state as MSB-first vector: state(1)=bit for x^order, state(order)=LSB
    state = zeros(1, order);
    for i = 1:order
        % bitget with position i extracts bit at weight 2^(i-1) (LSB=1)
        % we want state(1)=MSB -> bit position = order - 1 + 1 = order
        state(i) = bitget(uint32(seed), order - i + 1);
    end
    % ensure not all zeros
    if all(state==0)
        state(end) = 1;
    end

    out = zeros(1, Nout);
    % map polynomial degrees to state indices (MSB-first)
    taps_idx = order - taps + 1; % degree t -> index in state
    taps_idx = taps_idx(taps_idx>=1 & taps_idx<=order);

    for k = 1:Nout
        % output bit: take LSB (degree 1) OR take MSB depending on convention
        % We'll output the LSB (state(end)) to get typical PRBS ordering used elsewhere
        out(k) = state(end);

        % compute feedback as XOR of the tapped bits (using the provided degrees)
        fb = 0;
        for tt = taps_idx
            fb = bitxor(fb, state(tt));
        end

        % shift right by one position, insert feedback at MSB (state(1))
        state = [fb, state(1:end-1)];
    end
end