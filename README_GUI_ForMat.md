# Signal Generator GUI for MATLAB

## 简介

`signal_generator_gui.m` 是仓库内的 MATLAB 图形界面程序，用于交互式生成常见测试信号、在 GUI 中预览、对信号进行定点量化，并导出为 FPGA / 嵌入式常用的样本文件（`.hex` / `.mem` / `.bin` 等）。程序也支持从文件或工作区导入样本并还原为浮点波形以便预览和再导出。

本 README 针对代码实际实现（`signal_generator_gui.m`）做了功能说明与使用要点，便于在 MATLAB 环境下快速上手和对接硬件/仿真流程。

## 主要功能（与实现对应）

- 支持信号类型：Sine（正弦）、Square（方波）、PRBS（伪随机二进制序列）、White Noise（带限白噪声）。
- 动态参数面板：根据所选信号类型自动显示对应的参数输入控件（左侧参数面板）。
- 编码面板：右侧有编码参数区域，可选择 Integer / Q-format 以及 Signed/Unsigned，并设置总位宽 N 与 Fractional bits（Q）。
- 预览区：底部大图用于显示生成或导入的波形；PRBS 使用阶梯（stairs）绘制以反映离散跳变；为性能考虑会对预览数据做点数截断（默认 5000 点）。
- 导出：支持 `.hex` / `.mem`（文本十六进制行）和 `.bin`（原始字节流）等常见格式；导出前在 GUI 中会按当前编码参数将浮点信号量化为整数后写文件。
- 导入：支持导入 `.hex` / `.mem` / `.bin` / `.csv` 等格式，并在导入对话中支持使用伴随的 metadata JSON 文件（例如 `foo.bin.meta.json`）自动填充位宽、采样率等信息；导入对话可手工指定 `N bits`、`Frac bits`、`Signed/Unsigned`、`vmin/vmax`（用于 unsigned 恢复）和二进制的 bytes-per-sample。
- 工作区交互：可以从 MATLAB base workspace 导入变量，或把生成/编码后的数据导出到 workspace。
- 交互工具：支持缩放/平移/数据光标、保存图像，状态栏显示操作反馈。

## 快速上手

1. 将含本仓库的目录加入 MATLAB 路径或切换到该目录。
2. 在命令行运行：

    ```matlab
    signal_generator_gui
    ```

3. 在界面顶部选择信号类型与编码（Signed/Unsigned、Integer/Q-format），在左侧填写信号参数（例如 Amplitude、Frequency、Time、Sample rate 等），点击 `Generate & Preview` 查看模拟波形与量化后波形（右侧编码参数生效）。

4. 使用 `Export...` 保存为所需格式；若需要将目前生成的数据送回 MATLAB 环境，可使用 `Export to Workspace`。

5. 使用 `Import...` 加载已有样本文件，程序会尝试查找伴随的 meta 文件以自动填充参数，或通过对话手工输入参数完成恢复。

## 信号与参数（实现要点）

- Sine / Square：常见的振幅、偏置（Offset）、频率、相位、占空比（Square）等参数均在参数面板内。
- PRBS：实现为可配置的 LFSR（Fibonacci 风格，MSB-first），界面允许输入多项式 taps、阶（order）与 seed。PRBS 在预览时以阶梯显示；导出前会按当前编码参数量化。
- White Noise（带限白噪声）：提供 Lowcut / Highcut（Hz）和 FIR order 参数。实现中 FIR 设计优先使用 MATLAB 的 `fir1`（Signal Processing Toolbox），滤波时可选择使用零相位滤波（若可用）或因性能/工具箱限制退回到简单实现。

## 编码与导出细节

- Q-format：按用户指定的 frac bits 将信号乘以 2^frac 并四舍五入，然后截断到目标位宽并以二补数表示写入文件。
- Unsigned 整数：导出时程序会使用 signal 的峰值或用户给出的 vmin/vmax 将浮点值线性映射到 [0, 2^N−1]。
- 导出 `.bin`：按大端字节序写入，每样本使用 `ceil(Nbits/8)` 字节；导入对话允许用户指定 bytes-per-sample 以兼容不同来源。

## 导入流程与元数据

- 导入对话支持读取伴随的 JSON 元数据文件（常见名为 `name.meta.json` 或 `name.json`），若存在则跳过提示并直接使用元数据恢复浮点值。
- 如果没有元数据，Import 对话会让用户输入必要的编码参数（N bits / frac / Signed/Unsigned / vmin / vmax / fs / bytes per sample），并在读取后把还原的波形显示在预览区。

## 交互与预览行为

- 预览会在绘图前对过多点数做截断以保证 UI 响应（默认最多 5000 点，代码变量名为 MAX_PREVIEW_POINTS）。
- PRBS 使用 `stairs` 绘制以反映离散电平变化；其它信号使用 `plot`。
- 导入后会把整数样本保存在内部结构 `importedData` 中，并在状态栏显示导入源与样本数。

## 已知问题与建议（TODO）

- PRBS 生成需要进一步验证：虽然目前实现改为 MSB-first 的 Fibonacci LFSR 并增加了 taps 的可配置性，但仍建议补充一组参考向量（不同阶、不同 taps、已知 seed 下产生的比特序列）用于单元测试，以确认在各种参数下的周期性与统计特性符合预期。
- White Noise 的 FIR 设计依赖于 `fir1`（Signal Processing Toolbox）；若目标环境无该工具箱，建议在 README 或启动时提示用户，并提供回退选项或在导出前使用离线脚本完成滤波。

---

如有建议或需求，欢迎反馈。
