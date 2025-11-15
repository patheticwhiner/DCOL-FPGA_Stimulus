import sys
import math
import numpy as np
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import secrets
import os

try:
    from matplotlib.figure import Figure
    from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg, NavigationToolbar2Tk
except Exception:
    Figure = None

# Note: widgets (RectangleSelector) will be imported lazily when setting up the canvas


def generate_sine(num_samples, amplitude, frequency, phase, sample_rate):
    t = np.arange(num_samples) / float(sample_rate)
    return amplitude * np.sin(2 * np.pi * frequency * t + phase)


def generate_square(num_samples, amplitude, frequency, duty, sample_rate):
    t = np.arange(num_samples) / float(sample_rate)
    cycle = (t * frequency) % 1.0
    return amplitude * (np.where(cycle < duty, 1.0, -1.0))


def generate_prbs(num_samples, amplitude, seed=None, order=None, mode='lfsr'):
    """
    生成 PRBS 序列。

    参数:
      - num_samples: 采样点数
      - amplitude: ±振幅映射到 bit 为 0/1 映射为 -amp/+amp
      - seed: 整数种子（作为 LFSR 的初始状态或 RNG 种子）
      - order: LFSR 阶（如 7, 15, 31）；如果为 None，则回退到 RNG 模式
      - mode: 'lfsr' 或 'rng'，优先使用 lfsr 当 order 有效

    返回浮点数组（长度 num_samples），值为 ±amplitude
    """
    # 支持的 LFSR taps（zero-based bit indices）—常用的最大长度多项式 taps
    # Expanded taps table (zero-based bit indices). These are common maximal-length taps.
    taps_table = {
        5:  [4, 1],    # x^5 + x^2 + 1
        7:  [6, 5],    # x^7 + x^6 + 1
        9:  [8, 4],    # x^9 + x^5 + 1
        11: [10, 8],   # x^11 + x^9 + 1
        13: [12, 11, 10, 7],  # x^13 + x^12 + x^11 + x^8 + 1
        15: [14, 13],  # x^15 + x^14 + 1
        17: [16, 13],  # x^17 + x^14 + 1
        19: [18, 5],   # x^19 + x^6 + 1
        23: [22, 17],  # x^23 + x^18 + 1
        29: [28, 1],   # x^29 + x^2 + 1
        31: [30, 27],  # x^31 + x^28 + 1
    }

    # normalize mode
    mode = (mode or '').lower()
    use_lfsr = (mode == 'lfsr') and (order in taps_table)
    if use_lfsr:
        taps = taps_table[order]
        # validate taps
        if any((t < 0 or t >= order) for t in taps):
            # invalid taps for this order; fall back to RNG
            use_lfsr = False
        else:
            # 为提升速度，预计算 taps 的位掩码并用 bit_count 计算奇偶性，避免循环内多次索引
            mask = 0
            for t in taps:
                mask |= (1 << t)
            # bit_count helper (fallback for older Pythons)
            if hasattr(int, 'bit_count'):
                def _bitcount(x):
                    return x.bit_count()
            else:
                def _bitcount(x):
                    return bin(x).count('1')
        # 初始化寄存器：使用 seed 的低 order 位，若为 None 或 0 则使用全 1（避免全 0 锁死）
        if seed is None or int(seed) == 0:
            reg = (1 << order) - 1
        else:
            reg = int(seed) & ((1 << order) - 1)
            if reg == 0:
                reg = 1

        out = np.empty(num_samples, dtype=np.int8)
        for i in range(num_samples):
            bit = reg & 1
            out[i] = bit
            # 反馈位计算：使用位掩码并计算位计数的奇偶性
            fb = (_bitcount(reg & mask) & 1)
            # 右移并在最高位写入反馈
            reg = (reg >> 1) | (fb << (order - 1))
            # 防止意外进入全零状态
            if reg == 0:
                reg = (1 << order) - 1

        return amplitude * (2 * out - 1)

    # 回退到 RNG 模式（与之前实现兼容）
    rng = np.random.default_rng(seed)
    bits = rng.integers(0, 2, size=num_samples)
    return amplitude * (2 * bits - 1)


def generate_white_noise(num_samples, amplitude, sample_rate, lowcut, highcut, fir_order):
    """
    Generate band-limited white Gaussian noise. Try to use scipy.signal.firwin + lfilter
    (or filtfilt if available). If scipy is not available or filter design fails, fall back
    to raw Gaussian noise.

    lowcut, highcut in Hz. If lowcut <= 0 and highcut >= fs/2 -> return raw noise.
    """
    rng = np.random.default_rng()
    x = amplitude * rng.standard_normal(num_samples)
    fs = float(sample_rate)
    # sanitize
    lowf = max(0.0, float(lowcut))
    highf = float(highcut)
    nyq = fs / 2.0
    if highf <= 0 or highf <= lowf:
        return x
    if lowf <= 0 and highf >= nyq - 1e-9:
        return x
    # try to design FIR via scipy
    try:
        from scipy.signal import firwin, lfilter, filtfilt
        use_filtfilt = True
    except Exception:
        try:
            from scipy.signal import firwin, lfilter
            filtfilt = None
            use_filtfilt = False
        except Exception:
            # scipy not available
            return x

    numtaps = max(3, int(round(fir_order)))
    # ensure numtaps is odd for Type I linear phase
    if numtaps % 2 == 0:
        numtaps += 1

    try:
        if lowf <= 0:
            # lowpass
            cutoff = min(max(highf / nyq, 1e-6), 0.9999)
            b = firwin(numtaps, cutoff)
        elif highf >= nyq - 1e-9:
            # highpass
            cutoff = min(max(lowf / nyq, 1e-6), 0.9999)
            b = firwin(numtaps, cutoff, pass_zero=False)
        else:
            # bandpass
            wn = [max(lowf/nyq, 1e-6), min(highf/nyq, 0.9999)]
            if wn[1] <= wn[0]:
                return x
            b = firwin(numtaps, wn, pass_zero=False)
        # apply filter (use filtfilt if available to remove phase)
        if 'filtfilt' in globals() and filtfilt is not None:
            y = filtfilt(b, 1.0, x)
        else:
            y = lfilter(b, 1.0, x)
        return y
    except Exception:
        return x


def float_to_signed_twos(value, total_bits):
    mask = (1 << total_bits) - 1
    return int(value) & mask


def quantize_signed(values, total_bits, frac_bits):
    scale = 2 ** frac_bits
    max_int = 2 ** (total_bits - 1) - 1
    min_int = -2 ** (total_bits - 1)
    ints = np.round(values * scale).astype(np.int64)
    ints = np.clip(ints, min_int, max_int)
    # convert to unsigned representation (two's complement) for storage
    mask = (1 << total_bits) - 1
    uints = (ints & mask).astype(np.uint64)
    return uints


def quantize_unsigned(values, total_bits):
    # Shift to non-negative range and scale to full range
    vmin = values.min()
    shifted = values - vmin
    vmax = shifted.max()
    if vmax == 0:
        return np.zeros_like(shifted, dtype=np.uint64)
    scale = (2 ** total_bits - 1) / float(vmax)
    ints = np.round(shifted * scale).astype(np.uint64)
    return ints


def save_hex(lines, path):
    with open(path, 'w') as f:
        for v in lines:
            f.write(v + '\n')


def save_bin(uints, total_bits, path):
    bytes_per = (total_bits + 7) // 8
    with open(path, 'wb') as f:
        for v in uints:
            f.write(int(v).to_bytes(bytes_per, byteorder='big'))


def save_raw_csv(values, path):
    # Save floating point values as one value per line CSV
    try:
        np.savetxt(path, np.asarray(values), delimiter=',', fmt='%.18e')
    except Exception as e:
        raise


def save_raw_mat(values, sample_rate, path):
    # Try to use scipy.io.savemat; if unavailable, fallback to numpy savez
    try:
        from scipy import io as spio
        spio.savemat(path, {'samples': np.asarray(values), 'sample_rate': float(sample_rate)})
    except Exception:
        # fallback to npz
        try:
            np.savez(path, samples=np.asarray(values), sample_rate=float(sample_rate))
        except Exception:
            raise


def make_hex_lines(uints, total_bits):
    hex_digits = (total_bits + 3) // 4
    fmt = '{:0' + str(hex_digits) + 'X}'
    return [fmt.format(int(v)) for v in uints]


class SignalGeneratorApp:
    def __init__(self, root):
        self.root = root
        root.title('Signal Generator (FPGA Stimulus)')

        main = ttk.Frame(root, padding=8)
        main.pack(fill='both', expand=True)

        # Signal selection
        top = ttk.Frame(main)
        top.pack(fill='x')

        ttk.Label(top, text='Signal:').pack(side='left')
        self.sig_var = tk.StringVar(value='Sine')
        self.sig_cb = ttk.Combobox(top, textvariable=self.sig_var, state='readonly', width=16,
                                   values=['Sine', 'Square', 'White Noise', 'PRBS'])
        self.sig_cb.pack(side='left', padx=6)
        self.sig_cb.bind('<<ComboboxSelected>>', lambda e: self.build_params())

        # Fixed point selection（只保留下拉框，参数框只显示不可编辑）
        ttk.Label(top, text='Fixed format:').pack(side='left', padx=(12, 0))
        self.format_var = tk.StringVar(value='Signed')
        presets = ['Signed', 'Unsigned']
        self.format_cb = ttk.Combobox(top, textvariable=self.format_var, values=presets, state='readonly', width=12)
        self.format_cb.pack(side='left', padx=6)
        self.format_cb.bind('<<ComboboxSelected>>', lambda e: self.apply_preset())

        # Parameters frame
        self.param_frame = ttk.LabelFrame(main, text='Parameters')
        self.param_frame.pack(fill='x', pady=8)

        # Common params
        # Common params (Sample rate, Samples, Time on the same row)
        common = ttk.Frame(main)
        common.pack(fill='x')

        ttk.Label(common, text='Sample rate (Hz):').pack(side='left')
        self.sample_rate_var = tk.DoubleVar(value=48000.0)
        self.sample_rate_entry = ttk.Entry(common, textvariable=self.sample_rate_var, width=10)
        self.sample_rate_entry.pack(side='left', padx=6)

        # Time placed left of Samples per request. Default Time = 10 seconds.
        ttk.Label(common, text='Time (s):').pack(side='left', padx=(12, 0))
        init_time = 10.0
        self.time_var = tk.DoubleVar(value=init_time)
        self.time_entry = ttk.Entry(common, textvariable=self.time_var, width=10)
        self.time_entry.pack(side='left', padx=6)

        ttk.Label(common, text='Samples:').pack(side='left')
        # determine default samples from Time and Sample rate
        try:
            init_samples = max(1, int(round(init_time * float(self.sample_rate_var.get()))))
        except Exception:
            init_samples = 1024
        self.num_samples_var = tk.IntVar(value=init_samples)
        self.num_samples_entry = ttk.Entry(common, textvariable=self.num_samples_var, width=8)
        self.num_samples_entry.pack(side='left', padx=6)

        # internal flag to avoid recursive updates
        self._updating_time_related = False
        # add traces to keep Sample rate, Samples and Time linked:
        self.sample_rate_var.trace_add('write', lambda *a: self._on_sample_or_samples_changed())
        self.num_samples_var.trace_add('write', lambda *a: self._on_sample_or_samples_changed())
        self.time_var.trace_add('write', lambda *a: self._on_time_changed())

        # Dynamic parameter holders
        self.params = {}
        # 用于保存参数对应的控件引用；必须在 build_params 前初始化
        self.params_widgets = {}
        self.build_params()
        # 最大绘图点数（用来限制在高采样/大量样本时的绘图开销）
        self.max_plot_points = 5000

        # Preview canvas
        preview_frame = ttk.Frame(main)
        preview_frame.pack(fill='both', expand=True)

        if Figure is not None:
            self.fig = Figure(figsize=(6, 2.5), dpi=100)
            self.ax = self.fig.add_subplot(111)
            self.canvas = FigureCanvasTkAgg(self.fig, master=preview_frame)
            self.canvas.get_tk_widget().pack(fill='both', expand=True)
            # add matplotlib navigation toolbar (pan/zoom/home/save)
            try:
                self.toolbar = NavigationToolbar2Tk(self.canvas, preview_frame)
                self.toolbar.update()
                self.toolbar.pack()
            except Exception:
                self.toolbar = None

            # enable scroll-wheel zoom and rectangle selection zoom
            try:
                self.canvas.mpl_connect('scroll_event', self._on_scroll)
                # RectangleSelector: left-click and drag to zoom into the box
                try:
                    from matplotlib.widgets import RectangleSelector as _RectangleSelector
                except Exception:
                    _RectangleSelector = None
                if _RectangleSelector is not None:
                    self._rs = _RectangleSelector(self.ax, self._on_select,
                                                  drawtype='box', useblit=True,
                                                  button=[1], minspanx=5, minspany=5,
                                                  spancoords='data', interactive=True)
                else:
                    self._rs = None
            except Exception:
                self._rs = None
        else:
            ttk.Label(preview_frame, text='matplotlib not available: preview disabled').pack()

        # Buttons
        btns = ttk.Frame(main)
        btns.pack(fill='x', pady=6)

        ttk.Button(btns, text='Generate & Preview', command=self.on_preview).pack(side='left', padx=6)
        ttk.Button(btns, text='Export...', command=self.on_export).pack(side='left', padx=6)
        ttk.Button(btns, text='Import...', command=self.on_import).pack(side='left')

    def clear_param_widgets(self):
        for w in self.param_frame.winfo_children():
            w.destroy()
        self.params.clear()
        self.params_widgets.clear()

    def build_params(self):
        # 保存已有参数值以便在重建时恢复
        saved = {k: (v.get() if hasattr(v, 'get') else v) for k, v in self.params.items()}
        self.clear_param_widgets()
        # 创建左右两栏布局，右侧用于放置可选项（如 PRBS 的 Mode/Order）
        self.col_left = ttk.Frame(self.param_frame)
        self.col_left.pack(side='left', fill='both', expand=True)
        self.col_right = ttk.Frame(self.param_frame)
        self.col_right.pack(side='left', fill='both', expand=True, padx=(12, 0))
        sig = self.sig_var.get()
    # Add White Noise parameters similar to MATLAB GUI
        if sig == 'Sine':
            self._add_param('Amplitude', tk.DoubleVar(value=saved.get('Amplitude', 1.0)), column='left')
            self._add_param('Offset', tk.DoubleVar(value=saved.get('Offset', 0.0)), column='left')
            self._add_param('Frequency (Hz)', tk.DoubleVar(value=saved.get('Frequency (Hz)', 1000.0)), column='left')
            self._add_param('Phase (rad)', tk.DoubleVar(value=saved.get('Phase (rad)', 0.0)), column='left')
        elif sig == 'Square':
            self._add_param('Amplitude', tk.DoubleVar(value=saved.get('Amplitude', 1.0)), column='left')
            self._add_param('Offset', tk.DoubleVar(value=saved.get('Offset', 0.0)), column='left')
            self._add_param('Frequency (Hz)', tk.DoubleVar(value=saved.get('Frequency (Hz)', 1000.0)), column='left')
            self._add_param('Duty (0-1)', tk.DoubleVar(value=saved.get('Duty (0-1)', 0.5)), column='left')
        elif sig == 'PRBS':
            # PRBS 参数与其它模式保持在左侧以保持一致性
            # 首先放置 Mode（位于 Amplitude 上方）并绑定变化以便动态调整其余参数
            mode_val = saved.get('Mode', 'LFSR')
            self._add_param('Mode', tk.StringVar(value=mode_val), widget='combobox', values=['LFSR', 'RNG'], column='left')
            # 如果 Mode 改变，我们需要重建参数来显示对应的选项
            try:
                mv = self.params['Mode']
                mv.trace_add('write', lambda *a: self.build_params())
            except Exception:
                pass
            # 根据 Mode 显示不同参数：Amplitude 始终显示；Seed/Order 仅在需要时显示
            self._add_param('Amplitude', tk.DoubleVar(value=saved.get('Amplitude', 1.0)), column='left')
            self._add_param('Offset', tk.DoubleVar(value=saved.get('Offset', 0.0)), column='left')
            # prepare a non-trivial default seed (avoid 0/1 defaults). Use saved seed if present,
            # otherwise generate a random non-zero seed constrained by the default order.
            order_default = int(saved.get('Order', 13))
            try:
                default_seed = saved.get('Seed (int)', None)
                if default_seed is None:
                    bound = (1 << order_default) - 1
                    if bound <= 1:
                        default_seed = 1
                    else:
                        default_seed = secrets.randbelow(bound) + 1
            except Exception:
                default_seed = 1
            mode_now = self.params['Mode'].get() if 'Mode' in self.params else mode_val
            if mode_now == 'LFSR':
                self._add_param('Seed (int)', tk.IntVar(value=saved.get('Seed (int)', default_seed)), column='left')
                self._add_param('Order', tk.IntVar(value=saved.get('Order', 13)), column='left')
            else:
                # RNG 模式仅显示可选的种子
                self._add_param('Seed (int)', tk.IntVar(value=saved.get('Seed (int)', default_seed)), column='left')

        elif sig == 'White Noise':
            # Band-limited white Gaussian noise
            self._add_param('Amplitude', tk.DoubleVar(value=saved.get('Amplitude', 1.0)), column='left')
            self._add_param('Offset', tk.DoubleVar(value=saved.get('Offset', 0.0)), column='left')
            self._add_param('Lowcut (Hz)', tk.DoubleVar(value=saved.get('Lowcut (Hz)', 0.0)), column='left')
            # default highcut is Nyquist; user can set less
            self._add_param('Highcut (Hz)', tk.DoubleVar(value=saved.get('Highcut (Hz)', 24000.0)), column='left')
            # FIR order (num taps)
            self._add_param('FIR order', tk.IntVar(value=saved.get('FIR order', 101)), column='left')

        # Total bits / Fractional bits 可编辑（下拉只选择 Signed/Unsigned，不包含位宽细节）
        self._add_param('Total bits', tk.IntVar(value=saved.get('Total bits', 24)), column='right')
        self._add_param('Fractional bits', tk.IntVar(value=saved.get('Fractional bits', 23)), column='right')

    def _add_param(self, label, var, readonly=False, widget='entry', values=None, column='left'):
        """Add a parameter control into left or right column.

        widget: 'entry' or 'combobox'
        values: list of values for combobox
        column: 'left' or 'right'
        """
        parent = getattr(self, 'col_left', self.param_frame) if column == 'left' else getattr(self, 'col_right', self.param_frame)
        row = ttk.Frame(parent)
        row.pack(fill='x', padx=6, pady=2)
        ttk.Label(row, text=label + ':').pack(side='left')
        if widget == 'combobox':
            cb = ttk.Combobox(row, textvariable=var, state='readonly' if readonly else 'normal', values=values, width=10)
            cb.pack(side='left', padx=6)
            widget_ref = cb
        else:
            ent = ttk.Entry(row, textvariable=var, width=12)
            ent.pack(side='left', padx=6)
            if readonly:
                ent.config(state='readonly')
            widget_ref = ent

        self.params[label] = var
        self.params_widgets[label] = widget_ref

    def apply_preset(self):
        # 新逻辑：下拉只选择 Signed / Unsigned，不设置位宽细节。
        # - 若选择 Unsigned，则 Fractional bits 默认为 0 并设为只读（可通过输入框修改后恢复）。
        # - 若选择 Signed，则 Fractional bits 可编辑（恢复为可写）。
        v = self.format_var.get()
        try:
            if v == 'Unsigned':
                # 保留当前 total bits，但将小数位默认设置为 0 并设为只读
                self.params['Fractional bits'].set(0)
                self.params_widgets['Fractional bits'].config(state='readonly')
            else:
                # Signed: 允许编辑小数位
                # 如果当前小数位为 0，设置为一个合理默认（total-1）
                total = int(self.params['Total bits'].get()) if 'Total bits' in self.params else 16
                if int(self.params['Fractional bits'].get()) == 0:
                    self.params['Fractional bits'].set(max(1, total - 1))
                self.params_widgets['Fractional bits'].config(state='normal')
        except Exception:
            # 容错：不做任何改变
            pass

    def make_signal(self):
        sig = self.sig_var.get()
        num = int(self.num_samples_var.get())
        sr = float(self.sample_rate_var.get())
        amp = float(self.params['Amplitude'].get())
        # read optional offset parameter (default 0.0)
        offset = float(self.params['Offset'].get()) if 'Offset' in self.params else 0.0
        if sig == 'Sine':
            freq = float(self.params['Frequency (Hz)'].get())
            phase = float(self.params['Phase (rad)'].get())
            vals = generate_sine(num, amp, freq, phase, sr)
        elif sig == 'Square':
            freq = float(self.params['Frequency (Hz)'].get())
            duty = float(self.params['Duty (0-1)'].get())
            vals = generate_square(num, amp, freq, duty, sr)
        elif sig == 'PRBS':
            seed = int(self.params['Seed (int)'].get())
            if seed == 0:
                seed = None
            order = int(self.params.get('Order', tk.IntVar(value=13)).get()) if 'Order' in self.params else None
            mode = self.params.get('Mode', tk.StringVar(value='LFSR')).get() if 'Mode' in self.params else 'LFSR'
            vals = generate_prbs(num, amp, seed, order, mode=mode.lower())
        else:
            vals = np.zeros(num)

        if sig == 'White Noise':
            # For white noise we've already generated vals above as zeros; replace with generated noise
            try:
                lowcut = float(self.params.get('Lowcut (Hz)', tk.DoubleVar(value=0.0)).get()) if 'Lowcut (Hz)' in self.params else 0.0
                highcut = float(self.params.get('Highcut (Hz)', tk.DoubleVar(value=24000.0)).get()) if 'Highcut (Hz)' in self.params else float(sr) / 2.0
                fir_order = int(self.params.get('FIR order', tk.IntVar(value=101)).get()) if 'FIR order' in self.params else 101
                vals = generate_white_noise(num, amp, sr, lowcut, highcut, fir_order)
            except Exception:
                vals = generate_white_noise(num, amp, sr, 0.0, sr/2.0, 101)

        # apply offset (numpy array + scalar works)
        try:
            return vals + float(offset)
        except Exception:
            # fallback: convert to numpy array then add
            return np.array(vals) + float(offset)

    def _decimate_for_plot(self, arr):
        """Return (t_indices, arr_decimated) where arr_decimated has at most self.max_plot_points samples.
        Uses even decimation (linspace indices) to preserve overall shape when truncation is needed.
        """
        n = int(len(arr))
        m = min(n, int(self.max_plot_points))
        if n <= m:
            return np.arange(n), arr
        idx = np.linspace(0, n - 1, m).astype(int)
        return np.arange(m), arr[idx]

    def on_preview(self):
        vals = self.make_signal()
        total_bits = int(self.params['Total bits'].get())
        frac_bits = int(self.params['Fractional bits'].get())
        is_unsigned = (self.format_var.get() == 'Unsigned')

        if is_unsigned:
            u = quantize_unsigned(vals, total_bits)
        else:
            u = quantize_signed(vals, total_bits, frac_bits)

        if Figure is None:
            messagebox.showwarning('Preview', 'matplotlib not found; cannot show preview')
            return

        self.ax.clear()
        sig = self.sig_var.get()
        # decimate both the analog values and the reconstructed quantized trace to at most max_plot_points
        n = len(vals)
        t_plot, vals_plot = self._decimate_for_plot(vals)
        # compute reconstruction from full data, then decimate for plotting (so scaling uses full range)
        if is_unsigned:
            # reconstruct approx using full arrays
            vmin = vals.min()
            shifted = vals - vmin
            vmax = shifted.max() if shifted.max() != 0 else 1.0
            recon_full = (u.astype(float) / (2 ** total_bits - 1)) * vmax + vmin
        else:
            ui = u.astype(np.int64)
            sign_mask = 1 << (total_bits - 1)
            wrap = (ui & sign_mask) != 0
            if wrap.any():
                ui = np.where(wrap, ui - (1 << total_bits), ui)
            recon_full = ui / float(2 ** frac_bits)

        _, recon_plot = self._decimate_for_plot(recon_full)

        # For PRBS signals, draw the analog trace as stairs to reflect discrete levels.
        if sig == 'PRBS':
            try:
                edges = np.arange(len(vals_plot) + 1)
                self.ax.stairs(vals_plot, edges, label='Analog')
            except Exception:
                self.ax.step(t_plot, vals_plot, where='mid', label='Analog')
        else:
            self.ax.plot(t_plot, vals_plot, label='Analog')

        # draw quantized trace as dashed step to visually distinguish
        self.ax.step(t_plot, recon_plot, where='mid', label='Quantized', linestyle='--')
        self.ax.legend()
        self.ax.set_xlabel('Sample')
        self.canvas.draw()

    def _on_scroll(self, event):
        if event.inaxes != self.ax:
            return
        # zoom factor: scroll up -> zoom in, scroll down -> zoom out
        base_scale = 1.2
        cur_xlim = self.ax.get_xlim()
        cur_ylim = self.ax.get_ylim()
        xdata = event.xdata
        ydata = event.ydata
        if event.button == 'up':
            # zoom in
            scale_factor = 1 / base_scale
        else:
            # zoom out
            scale_factor = base_scale

        new_width = (cur_xlim[1] - cur_xlim[0]) * scale_factor
        new_height = (cur_ylim[1] - cur_ylim[0]) * scale_factor

        relx = (xdata - cur_xlim[0]) / (cur_xlim[1] - cur_xlim[0])
        rely = (ydata - cur_ylim[0]) / (cur_ylim[1] - cur_ylim[0])

        new_x0 = xdata - relx * new_width
        new_x1 = xdata + (1 - relx) * new_width
        new_y0 = ydata - rely * new_height
        new_y1 = ydata + (1 - rely) * new_height

        self.ax.set_xlim(new_x0, new_x1)
        self.ax.set_ylim(new_y0, new_y1)
        self.canvas.draw_idle()

    def _on_select(self, eclick, erelease):
        # eclick and erelease are matplotlib events with xdata/ydata
        x1, y1 = eclick.xdata, eclick.ydata
        x2, y2 = erelease.xdata, erelease.ydata
        if None in (x1, y1, x2, y2):
            return
        self.ax.set_xlim(min(x1, x2), max(x1, x2))
        self.ax.set_ylim(min(y1, y2), max(y1, y2))
        self.canvas.draw_idle()

    def on_import(self):
        """Open an import dialog to load previously exported samples.

        Supported file types: .hex, .mem (text hex per line), .bin (raw bytes).
        User must specify Total bits, Fractional bits and Signed/Unsigned to
        correctly reconstruct values. For Unsigned, user can provide vmin/vmax
        to restore original floating range.
        """
        dlg = tk.Toplevel(self.root)
        dlg.title('Import samples')
        dlg.transient(self.root)
        # position dialog near main window (same offset used for export)
        try:
            self.root.update_idletasks()
            rx = self.root.winfo_rootx()
            ry = self.root.winfo_rooty()
            dlg.geometry('+%d+%d' % (rx + 60, ry + 60))
        except Exception:
            pass
        dlg.grab_set()

        row = ttk.Frame(dlg, padding=6)
        row.pack(fill='x')

        # Import type selector (Quantized / Raw)
        ttk.Label(row, text='Import type:').grid(row=0, column=0, sticky='w')
        import_type_var = tk.StringVar(value='Quantized')
        import_type_cb = ttk.Combobox(row, textvariable=import_type_var, values=['Quantized', 'Raw'], state='readonly', width=12)
        import_type_cb.grid(row=0, column=1, sticky='w', padx=6)

        ttk.Label(row, text='File:').grid(row=1, column=0, sticky='w')
        file_var = tk.StringVar(value='')
        file_entry = ttk.Entry(row, textvariable=file_var, width=48)
        file_entry.grid(row=1, column=1, columnspan=2, padx=6, pady=2)
        def browse():
            itype = import_type_var.get()
            if itype == 'Raw':
                ftypes = [('CSV (.csv)', '*.csv'), ('MAT (.mat)', '*.mat'), ('NPZ (.npz)', '*.npz'), ('All','*.*')]
            else:
                ftypes = [('Hex (.hex)', '*.hex'), ('Memory (.mem)', '*.mem'), ('Binary (.bin)', '*.bin'), ('All','*.*')]
            p = filedialog.askopenfilename(defaultextension='*.*', filetypes=ftypes)
            if p:
                file_var.set(p)
        ttk.Button(row, text='Browse...', command=browse).grid(row=1, column=3, padx=6)

        # Signed combobox (moved to same row as Import type)
        signed_label = ttk.Label(row, text='Signed:')
        signed_label.grid(row=0, column=2, sticky='e')
        signed_var = tk.StringVar(value=self.format_var.get())
        signed_cb = ttk.Combobox(row, textvariable=signed_var, values=['Signed','Unsigned'], width=10, state='readonly')
        signed_cb.grid(row=0, column=3, sticky='w', padx=6)

        # Total bits and fractional bits (may be hidden depending on format)
        totalbits_label = ttk.Label(row, text='Total bits:')
        totalbits_label.grid(row=2, column=0, sticky='w')
        totalbits_var = tk.IntVar(value=int(self.params.get('Total bits', tk.IntVar(value=24)).get() if 'Total bits' in self.params else 24))
        totalbits_entry = ttk.Entry(row, textvariable=totalbits_var, width=8)
        totalbits_entry.grid(row=2, column=1, sticky='w', padx=6)

        fracbits_label = ttk.Label(row, text='Fractional bits:')
        fracbits_label.grid(row=2, column=2, sticky='e')
        fracbits_var = tk.IntVar(value=int(self.params.get('Fractional bits', tk.IntVar(value=23)).get() if 'Fractional bits' in self.params else 0))
        frac_entry = ttk.Entry(row, textvariable=fracbits_var, width=8)
        frac_entry.grid(row=2, column=3, sticky='w', padx=6)

        # vmin/vmax for unsigned reconstruction (only for text/hex formats)
        vmin_label = ttk.Label(row, text='vmin (for unsigned):')
        vmin_label.grid(row=3, column=0, sticky='w')
        vmin_var = tk.DoubleVar(value=0.0)
        vmin_entry = ttk.Entry(row, textvariable=vmin_var, width=10)
        vmin_entry.grid(row=3, column=1, sticky='w', padx=6)
        vmax_label = ttk.Label(row, text='vmax (for unsigned):')
        vmax_label.grid(row=3, column=2, sticky='e')
        vmax_var = tk.DoubleVar(value=1.0)
        vmax_entry = ttk.Entry(row, textvariable=vmax_var, width=10)
        vmax_entry.grid(row=3, column=3, sticky='w', padx=6)

        ttk.Label(row, text='Sample rate (Hz):').grid(row=4, column=0, sticky='w')
        sr_var = tk.DoubleVar(value=float(self.sample_rate_var.get()))
        ttk.Entry(row, textvariable=sr_var, width=10).grid(row=4, column=1, sticky='w', padx=6)

        msg_var = tk.StringVar(value='')
        msg_lbl = ttk.Label(dlg, textvariable=msg_var, foreground='red')
        msg_lbl.pack(fill='x', padx=6, pady=(4,0))

        btn_row = ttk.Frame(dlg)
        btn_row.pack(fill='x', pady=6)

        def update_import_params(*a):
            # Determine behavior based on selected import type first
            itype = import_type_var.get() if 'import_type_var' in locals() or 'import_type_var' in globals() else 'Quantized'
            p = file_var.get().strip()
            ext = os.path.splitext(p)[1].lower()

            if itype == 'Raw':
                # Raw import: hide quantized-specific controls (signed, total/frac bits, vmin/vmax)
                try:
                    signed_label.grid_remove()
                    signed_cb.grid_remove()
                    totalbits_label.grid_remove()
                    totalbits_entry.grid_remove()
                    fracbits_label.grid_remove()
                    frac_entry.grid_remove()
                    vmin_label.grid_remove()
                    vmin_entry.grid_remove()
                    vmax_label.grid_remove()
                    vmax_entry.grid_remove()
                except Exception:
                    pass
                return

            # Otherwise (Quantized): infer from file extension
            # by default show hex-like options when unknown
            show_hex_like = False
            show_bin = False
            if ext == '.bin':
                show_bin = True
            elif ext in ('.hex', '.mem'):
                show_hex_like = True
            else:
                show_hex_like = True

            # For both hex/mem and bin we need Signed/Total/Frac; vmin/vmax only for unsigned mapping (text/unsigned)
            if show_bin or show_hex_like:
                signed_label.grid()
                signed_cb.grid()
                totalbits_label.grid()
                totalbits_entry.grid()
                fracbits_label.grid()
                frac_entry.grid()
            else:
                signed_label.grid_remove()
                signed_cb.grid_remove()
                totalbits_label.grid_remove()
                totalbits_entry.grid_remove()
                fracbits_label.grid_remove()
                frac_entry.grid_remove()

            # vmin/vmax only useful for unsigned text-like formats
            if show_hex_like:
                vmin_label.grid()
                vmin_entry.grid()
                vmax_label.grid()
                vmax_entry.grid()
            else:
                vmin_label.grid_remove()
                vmin_entry.grid_remove()
                vmax_label.grid_remove()
                vmax_entry.grid_remove()

        # call update when file path or import type changes
        try:
            file_var.trace_add('write', update_import_params)
            import_type_var.trace_add('write', update_import_params)
        except Exception:
            try:
                file_var.trace('w', update_import_params)
                import_type_var.trace('w', update_import_params)
            except Exception:
                pass

        # ensure initial visibility is correct
        update_import_params()

        def do_load():
            p = file_var.get()
            if not p:
                messagebox.showerror('Import', 'Please select a file to import')
                return
            # infer format from file extension
            ext = os.path.splitext(p)[1].lower()
            # decide based on import type first
            itype = import_type_var.get()
            if itype == 'Raw':
                if ext == '.csv':
                    ffmt = 'csv'
                elif ext == '.mat':
                    ffmt = 'mat'
                elif ext == '.npz':
                    ffmt = 'npz'
                else:
                    # default to csv for unknown raw
                    ffmt = 'csv'
            else:
                if ext == '.bin':
                    ffmt = 'bin'
                elif ext == '.mem':
                    ffmt = 'mem'
                elif ext == '.hex':
                    ffmt = 'hex'
                else:
                    # default to hex for unknown quantized
                    ffmt = 'hex'
            tb = int(totalbits_var.get())
            fb = int(fracbits_var.get())
            signed = (signed_var.get() == 'Signed')
            try:
                if ffmt in ('hex','mem'):
                    with open(p, 'r') as f:
                        lines = [l.strip() for l in f.readlines() if l.strip()]
                    uints = []
                    hex_digits = (tb + 3) // 4
                    for ln in lines:
                        v = ln
                        if v.startswith('0x') or v.startswith('0X'):
                            v = v[2:]
                        # pad or trim
                        if len(v) > hex_digits:
                            # allow but warn: trim higher digits
                            v = v[-hex_digits:]
                        v = v.rjust(hex_digits, '0')
                        try:
                            ui = int(v, 16)
                        except Exception:
                            raise ValueError(f'Invalid hex line: {ln}')
                        uints.append(ui)
                    uints = np.array(uints, dtype=np.uint64)
                elif ffmt == 'bin':
                    bytes_per = (tb + 7) // 8
                    with open(p, 'rb') as f:
                        data = f.read()
                    if len(data) % bytes_per != 0:
                        raise ValueError('Binary file size is not a multiple of bytes per sample')
                    uints = []
                    for i in range(0, len(data), bytes_per):
                        chunk = data[i:i+bytes_per]
                        ui = int.from_bytes(chunk, byteorder='big')
                        uints.append(ui)
                    uints = np.array(uints, dtype=np.uint64)
                elif ffmt in ('csv','mat','npz'):
                    # Raw imports: read floats from CSV/MAT/NPZ
                    if ffmt == 'csv':
                        data = np.loadtxt(p, delimiter=',')
                    elif ffmt == 'mat':
                        try:
                            from scipy import io as spio
                            mat = spio.loadmat(p)
                            # try common keys
                            if 'samples' in mat:
                                data = np.asarray(mat['samples']).squeeze()
                            else:
                                # pick the first numeric variable
                                for k, v in mat.items():
                                    if not k.startswith('__'):
                                        data = np.asarray(v).squeeze()
                                        break
                        except Exception:
                            # fallback: try numpy.load
                            npz = np.load(p, allow_pickle=True)
                            if 'samples' in npz:
                                data = np.asarray(npz['samples']).squeeze()
                            else:
                                # pick first array-like
                                keys = [k for k in npz.keys()]
                                data = np.asarray(npz[keys[0]]).squeeze()
                    else:  # npz
                        npz = np.load(p, allow_pickle=True)
                        if 'samples' in npz:
                            data = np.asarray(npz['samples']).squeeze()
                        else:
                            keys = [k for k in npz.keys()]
                            data = np.asarray(npz[keys[0]]).squeeze()
                    # normalize data to 1D array
                    if data.ndim > 1:
                        # pick first column if 2D, else flatten
                        if data.shape[1] >= 1:
                            data = data[:,0]
                        else:
                            data = data.ravel()
                    recon = data.astype(float)
                else:
                    raise ValueError('Unsupported format')
                if uints.size == 0:
                    raise ValueError('No samples found in file')

                # reconstruct floats
                if signed:
                    ui64 = uints.astype(np.int64)
                    sign_mask = 1 << (tb - 1)
                    wrap = (ui64 & sign_mask) != 0
                    if wrap.any():
                        ui64 = np.where(wrap, ui64 - (1 << tb), ui64)
                    recon = ui64.astype(float) / float(2 ** fb)
                else:
                    # need vmin/vmax to map back to float
                    vmin = float(vmin_var.get())
                    vmax = float(vmax_var.get())
                    if vmax <= vmin:
                        raise ValueError('vmax must be greater than vmin for unsigned reconstruction')
                    recon = (uints.astype(float) / (2 ** tb - 1)) * (vmax - vmin) + vmin

                # apply sample rate and update UI
                self.num_samples_var.set(int(uints.size))
                self.sample_rate_var.set(float(sr_var.get()))
                # update fixed-point fields
                self.format_var.set('Signed' if signed else 'Unsigned')
                # ensure params exist and set
                if 'Total bits' in self.params:
                    self.params['Total bits'].set(tb)
                if 'Fractional bits' in self.params:
                    self.params['Fractional bits'].set(fb)

                # plot imported data in preview
                # plot imported data in preview (decimate to avoid UI lag)
                self.ax.clear()
                t_plot, recon_plot = self._decimate_for_plot(recon)
                try:
                    edges = np.arange(len(recon_plot) + 1)
                    self.ax.stairs(recon_plot, edges, label='Imported', linestyle='-')
                except Exception:
                    self.ax.plot(t_plot, recon_plot, label='Imported')
                self.ax.legend()
                self.canvas.draw()

                messagebox.showinfo('Import', f'Imported {len(recon)} samples from {p}')
                dlg.destroy()
            except Exception as e:
                messagebox.showerror('Import error', str(e))

        ttk.Button(btn_row, text='Load', command=do_load).pack(side='right', padx=6)
        ttk.Button(btn_row, text='Cancel', command=dlg.destroy).pack(side='right')

    def _on_sample_or_samples_changed(self):
        # update Time = Samples / SampleRate when Sample rate or Samples change
        if self._updating_time_related:
            return
        try:
            sr = float(self.sample_rate_var.get())
            ns = int(self.num_samples_var.get())
        except Exception:
            return
        try:
            self._updating_time_related = True
            t = ns / sr if sr != 0 else 0.0
            self.time_var.set(t)
        finally:
            self._updating_time_related = False

    def _on_time_changed(self):
        # update Samples = round(Time * SampleRate) when Time changes
        if self._updating_time_related:
            return
        try:
            sr = float(self.sample_rate_var.get())
            t = float(self.time_var.get())
        except Exception:
            return
        try:
            self._updating_time_related = True
            ns = int(round(t * sr))
            # keep at least 1 sample
            ns = max(1, ns)
            self.num_samples_var.set(ns)
        finally:
            self._updating_time_related = False

    def on_export(self):
        # Open an export dialog to choose Quantized or Raw export
        dlg = tk.Toplevel(self.root)
        dlg.title('Export samples')
        dlg.transient(self.root)
        # position dialog near main window to improve discoverability
        try:
            self.root.update_idletasks()
            rx = self.root.winfo_rootx()
            ry = self.root.winfo_rooty()
            # offset slightly so dialog doesn't overlap exactly
            dlg.geometry('+%d+%d' % (rx + 60, ry + 60))
        except Exception:
            pass
        dlg.grab_set()

        row = ttk.Frame(dlg, padding=6)
        row.pack(fill='x')

        ttk.Label(row, text='Export type:').grid(row=0, column=0, sticky='w')
        mode_var = tk.StringVar(value='Quantized')
        mode_cb = ttk.Combobox(row, textvariable=mode_var, values=['Quantized', 'Raw'], state='readonly', width=12)
        mode_cb.grid(row=0, column=1, sticky='w', padx=6)

        ttk.Label(row, text='Format:').grid(row=1, column=0, sticky='w')
        fmt_var = tk.StringVar(value='hex')
        # init values based on current mode
        initial_fmt_values = ['hex', 'mem', 'bin'] if mode_var.get() == 'Quantized' else ['csv', 'mat', 'npz']
        fmt_cb = ttk.Combobox(row, textvariable=fmt_var, values=initial_fmt_values, width=12, state='readonly')
        fmt_cb.grid(row=1, column=1, sticky='w', padx=6)

        # when mode changes, update available formats
        def _on_mode_change(*a):
            m = mode_var.get()
            if m == 'Quantized':
                fmt_cb.config(values=['hex', 'mem', 'bin'])
                if fmt_var.get() not in ('hex', 'mem', 'bin'):
                    fmt_var.set('hex')
            else:
                fmt_cb.config(values=['csv', 'mat', 'npz'])
                if fmt_var.get() not in ('csv', 'mat', 'npz'):
                    fmt_var.set('csv')

        try:
            mode_var.trace_add('write', _on_mode_change)
        except Exception:
            try:
                mode_var.trace('w', _on_mode_change)
            except Exception:
                pass

        ttk.Label(row, text='File:').grid(row=2, column=0, sticky='w')
        path_var = tk.StringVar(value='')
        path_entry = ttk.Entry(row, textvariable=path_var, width=48)
        path_entry.grid(row=2, column=1, columnspan=2, padx=6, pady=2)

        def browse():
            m = mode_var.get()
            if m == 'Quantized':
                ftypes = [('Hex (.hex)', '*.hex'), ('Memory (.mem)', '*.mem'), ('Binary (.bin)', '*.bin')]
            else:
                ftypes = [('CSV (.csv)', '*.csv'), ('MAT (.mat)', '*.mat'), ('NPZ (.npz)', '*.npz')]
            p = filedialog.asksaveasfilename(defaultextension='.' + fmt_var.get(), filetypes=ftypes)
            if p:
                path_var.set(p)
                # attempt to infer format
                low = p.lower()
                if low.endswith('.bin'):
                    fmt_var.set('bin')
                elif low.endswith('.hex'):
                    fmt_var.set('hex')
                elif low.endswith('.mem'):
                    fmt_var.set('mem')
                elif low.endswith('.csv'):
                    fmt_var.set('csv')
                elif low.endswith('.mat'):
                    fmt_var.set('mat')
                elif low.endswith('.npz'):
                    fmt_var.set('npz')

        ttk.Button(row, text='Browse...', command=browse).grid(row=2, column=3, padx=6)

        msg_var = tk.StringVar(value='')
        msg_lbl = ttk.Label(dlg, textvariable=msg_var, foreground='red')
        msg_lbl.pack(fill='x', padx=6, pady=(4,0))

        btn_row = ttk.Frame(dlg)
        btn_row.pack(fill='x', pady=6)

        def do_save():
            p = path_var.get()
            if not p:
                messagebox.showerror('Export', 'Please select a file to save')
                return
            m = mode_var.get()
            try:
                vals = self.make_signal()
                total_bits = int(self.params['Total bits'].get())
                frac_bits = int(self.params['Fractional bits'].get())
                is_unsigned = (self.format_var.get() == 'Unsigned')

                if m == 'Quantized':
                    if is_unsigned:
                        u = quantize_unsigned(vals, total_bits)
                    else:
                        u = quantize_signed(vals, total_bits, frac_bits)
                    low = p.lower()
                    if low.endswith('.hex') or low.endswith('.mem') or fmt_var.get() in ('hex','mem'):
                        lines = make_hex_lines(u, total_bits)
                        save_hex(lines, p)
                    elif low.endswith('.bin') or fmt_var.get() == 'bin':
                        save_bin(u, total_bits, p)
                    else:
                        # fallback to hex
                        lines = make_hex_lines(u, total_bits)
                        save_hex(lines, p)
                    messagebox.showinfo('Export', f'Exported {len(u)} samples to {p}')
                else:
                    low = p.lower()
                    if low.endswith('.csv') or fmt_var.get() == 'csv':
                        save_raw_csv(vals, p)
                        messagebox.showinfo('Export', f'Exported {len(vals)} samples to {p} (CSV)')
                    elif low.endswith('.mat') or fmt_var.get() == 'mat':
                        try:
                            save_raw_mat(vals, float(self.sample_rate_var.get()), p)
                            messagebox.showinfo('Export', f'Exported {len(vals)} samples to {p} (MAT)')
                        except Exception:
                            # fallback to npz
                            save_raw_mat(vals, float(self.sample_rate_var.get()), p)
                            messagebox.showinfo('Export', f'Exported {len(vals)} samples to {p} (NPZ fallback)')
                    elif low.endswith('.npz') or fmt_var.get() == 'npz':
                        # use numpy savez
                        np.savez(p, samples=np.asarray(vals), sample_rate=float(self.sample_rate_var.get()))
                        messagebox.showinfo('Export', f'Exported {len(vals)} samples to {p} (NPZ)')
                    else:
                        # default to CSV
                        save_raw_csv(vals, p)
                        messagebox.showinfo('Export', f'Exported {len(vals)} samples to {p} (CSV)')
                dlg.destroy()
            except Exception as e:
                messagebox.showerror('Export error', str(e))

        ttk.Button(btn_row, text='Save', command=do_save).pack(side='right', padx=6)
        ttk.Button(btn_row, text='Cancel', command=dlg.destroy).pack(side='right')


def main():
    root = tk.Tk()
    app = SignalGeneratorApp(root)
    root.mainloop()


if __name__ == '__main__':
    main()
