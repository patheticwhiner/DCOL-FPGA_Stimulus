# Signal Generator GUI for MATLAB

`signal_generator_gui.m` 是仓库内的 MATLAB 图形界面程序，用于交互式生成常见测试信号、在 GUI 中预览、对信号进行定点量化，并导出为 FPGA / 嵌入式常用的样本文件（`.hex` / `.mem` / `.bin` 等）。程序也支持从文件或工作区导入样本并还原为浮点波形以便预览和再导出。本 README 针对代码实际实现（`signal_generator_gui.m`）做了功能说明与使用要点，便于在 MATLAB 环境下快速上手和对接硬件/仿真流程。

<img src="assets\MATLAB_Interface.png" alt="MATLAB_Interface" />

## 主要功能

1. **信号发生器**：使用用户自定义参数生成实验常用信号，提供方便的便携操作

   - 支持信号类型：Sine（正弦）、Square（方波）、PRBS（伪随机二进制序列）、White Noise（带限白噪声）。
   - 动态参数面板：根据所选信号类型自动显示对应的参数输入控件（左侧参数面板）。
2. **外部信号/数据导入**：为了使工具的核心功能适用于更广泛的信号类型，工具提供从外部导入信号的选项

   + 文件导入：支持导入 `.hex` / `.mem` / `.bin` / `.csv` 等格式，并在导入对话中支持使用伴随的 metadata JSON 文件（例如 `foo.bin.meta.json`）自动填充位宽、采样率等信息；导入对话可手工指定 `N bits`、`Frac bits`、`Signed/Unsigned`、`vmin/vmax`（用于 unsigned 恢复）和二进制的 bytes-per-sample。
   + 工作区导入：可以从 MATLAB base workspace 导入变量
3. **编码转换与图像化（核心功能）**

   - 编码面板：右侧有编码参数区域，可选择 Integer / Q-format 以及 Signed/Unsigned，并设置总位宽 N 与 Fractional bits（Q）。
   - 预览区：底部大图用于显示生成或导入的波形；PRBS 使用阶梯（stairs）绘制以反映离散跳变；为性能考虑会对预览数据做点数截断（默认 5000 点）。另外提供MATLAB的图窗交互工具：以支持缩放/平移/数据光标、保存图像，状态栏显示操作反馈。
4. **数据导出**

   + 导出：支持 `.hex` / `.mem`（文本十六进制行）和 `.bin`（原始字节流）等常见格式；导出前在 GUI 中会按当前编码参数将浮点信号量化为整数后写文件。

   - 工作区导出：可以把生成/编码后的数据导出到 MATLAB workspace。

## 快速上手

1. 将含本仓库的目录加入 MATLAB 路径或切换到该目录。
2. 在命令行运行：

   ```matlab
   signal_generator_gui
   ```
3. 在界面顶部选择信号类型与编码（Signed/Unsigned、Integer/Q-format），在左侧填写信号参数（例如 Amplitude、Frequency、Time、Sample rate 等），点击 `Generate & Preview` 查看模拟波形与量化后波形（右侧编码参数生效）。
4. 使用 `Export...` 保存为所需格式；若需要将目前生成的数据送回 MATLAB 环境，可使用 `Export to Workspace`。
5. 使用 `Import...` 加载已有样本文件，程序会尝试查找伴随的 meta 文件以自动填充参数，或通过对话手工输入参数完成恢复。
6. 使用 `Import from Workspace` 可直接导入 MATLAB base workspace 中的变量（支持浮点或整数），导入后会覆盖当前数据。

## 1 信号生成

UI工具提供两种信号来源，一种是使用工具预设的信号自定义，另一种是从外部信号导入，本节首先介绍自定义信号的生成。首先在Signal下拉框内选择预设的几种信号类型之一，其次在Parameters参数块中填写信号的关键参数，最后点击Generate & Preview即可使参数生成出来，并绘制在预览框内。

- **正弦信号（Sine）**：可选参数包括振幅、偏置（Offset）、频率、相位等参数均在参数面板内；

  - 单一路径（与旧行为一致）：`Amplitude` = `1`，`Frequency (Hz)` = `50`，`Phase (deg)` = `0`。
  - 多分量叠加（等长或标量自动广播）：`Amplitude` = `[1 0.5]`，`Frequency (Hz)` = `[100 50]`，`Phase (deg)` = `[0 90]` —— 对应输出 y(t)=1*sin(2π100t)+0.5*sin(2π50t+90°)。
  - 也支持用逗号分隔：`1,0.5`，或带括号的 MATLAB 表达式：`[1, 0.5]`。
    Offset （偏置）仍支持标量偏置；若输入向量且长度等于生成的样本点数（Duration*SampleRate），则按样点逐点相加；否则会取第一个元素作为标量偏置并广播到全时域。
- **方波信号（Square）**：可选参数包括振幅、偏置（Offset）、频率、相位、占空比（Square）等参数均在参数面板内；

  <figure align = center>
      <img src="assets\genSine.png" width = 48% />
  	<img src="assets\genSquare.png" width = 48%/>  
  </figure>
- **带限白噪声信号（White Noise）**：除上述基本参数外，还提供带限频带参数，具体而言包括 Lowcut / Highcut（Hz）和 FIR order 参数。实现中 FIR 设计优先使用 MATLAB 的 `fir1`（Signal Processing Toolbox）。
- **伪随机二进制序列（PRBS）**：实现为可配置的 LFSR（Fibonacci 风格，MSB-first），UI提供的关键参数包括：输入多项式 taps、阶（order）与 seed。PRBS 在预览时以阶梯图形式显示。

  <figure align = center>
      <img src="assets\genWhiteNoise.png" width = 48% />
  	<img src="assets\genPRBS.png" width = 48%/>  
  </figure>

## 2 信号导入

有时候，我们也会遇到所需信号不是预设信号的情况，此时可以将所需信号通过**文件导入（Import）**或者**工作区导入（Import from Workspace）**两种方式导入到UI工具中、量化再进一步导出。

为了调试工具的这一功能，工程中提供了 `generate_multisine.m`脚本用于生成外部数据。

+ **工作区导入（Import from Workspace）**：点击Import from Workspace会给出弹窗，请用户选择工作区数据，再点击确定后，数据将会导入到系统中存储，并在预览窗口中显示出来。此时可以按照两类数据类型导入

  + 原数据（Raw Data）：直接导入数据，与使用Signal Generator所生成的数据一致
  + 二进制数据（Quantized Data）：将数据导入为量化数据，与生成信号的量化数据一致

    <figure align = center>
        <img src = "assets\importOpts.png" width = 15%>
        <img src="assets\importOpts2.png" width = 24%/>
    	<img src="assets\importMSine.png" width = 60%/>  
    </figure>
+ **文件导入（Import）**：与从工作区导入仅有数据来源不同，其它设置完全相同。这部分最重要的工作是**正确解码文件数据**。

*注：所有导入数据（文件/工作区）都会覆盖当前数据，且统一存入 `importedData` 结构体。*

## 3 编码与交互预览

本节列出 GUI 中与编码和预览交互最相关的选项与行为，优先说明最常见且会影响导出/恢复的设置。

- **量化选项（Quantize）**：控制是否在预览中叠加量化后的曲线，以便快速评估量化误差。

  - Quantize = ON：在预览上叠加量化后的曲线（overlay），用于观察量化引入的误差和失真。通常在调整 `N bits` / `frac` 或映射范围时打开。
  - Quantize = OFF：只显示原始浮点波形（no overlay），适用于检查未量化的信号形状。

  <figure align = center>
      <img src="assets\quantize.png" width = 48% />
      <img src="assets\quantize2.png" width = 48%/>  
  </figure>
- **编码选项（Encoding）**：右侧编码面板用于设置导出/恢复时的数值格式。下面分别详细说明常用格式的处理方式。

  - **Q-format (定点 Q)**：

    - 导出流程：按用户指定的 `frac` bits，将浮点信号乘以 2^frac、四舍五入并截断为 `N` 位，最终以二补数形式写入文件。
    - 恢复/预览：从整数恢复时将整数视为有符号 Q 值并除以 2^frac 以得到浮点近似。
  - **Unsigned 整数（无符号）**：

    - 导出流程：使用信号峰值（或用户在导入对话中指定的 `vmin`/`vmax`）做线性归一化，将浮点范围映射到 `[0, 2^N-1]` 并写入文件。
    - 恢复/预览：解码时将整数映射回 `[-1,1]`（或基于保存的 `vmin`/`vmax` 还原到原始幅值范围）。
  - **Signed（二补数）**：

    - 导出流程：先将信号按峰值归一化到 `[-1,1]`，再缩放到带符号的整数范围并写入二补数表示的整数值。
    - 恢复/预览：按带符号整数解读并反向缩放到原幅值近似。
- **预览行为（Preview）**：

  - 为保证界面响应与交互流畅，预览会在绘图前对过多点数的信号做截断（默认最多 `5000` 点，对应代码变量 `MAX_PREVIEW_POINTS`）。
  - PRBS 等离散跳变信号使用阶梯图（`stairs`）以反映样本间的突变；连续信号使用常规 `plot`。

## 4 数据导出

本节说明导出行为、推荐用法及不同文件格式的注意事项，优先提示会影响导出结果的开关（例如 `Quantize`）。

- **量化与导出（Quantize）**：

  - 当 `Quantize = ON` 时，`Export...` 与 `Export to Workspace` 导出**量化后的整数数据**（即 `intVals`，或由 `floatY` + 当前编码参数生成的整数）。
  - 当 `Quantize = OFF` 时，导出**原始浮点数据**（即 `floatY`）；建议使用 CSV 格式保存到文件，导出到工作区时为浮点向量。

  <figure align = center>
      <img src="assets\exportQuantize.png" width = 48% />
      <img src="assets\exportQuantize2.png" width = 48%/>  
  </figure>
- **支持的文件格式与推荐**：

  - **`.hex` / `.mem` / `.coe` / `.mif`**：文本格式，通常每行表示一个样本的整数（十六进制或特定的 COE/MIF 头）。适合用于 FPGA 初始化或仿真输入。导出时请确认 `N bits` 与格式约定（行宽、字节序等）。
  - **`.bin`（原始字节流）**：适用于需要紧凑二进制样本的场合；工具按照大端字节序写入（注意：目标系统可能期望小端或大端，请据实调整）。每样本使用 `ceil(Nbits/8)` 字节写入；导入对话提供 `bytes-per-sample` 选项以兼容不同来源。
  - **`.csv`（逗号分隔）**：适合保存原始浮点数据或便于用电子表格/脚本查看。导出浮点时建议使用 CSV；导入时请确保没有表头或先行去除表头以避免解析错误。
- **导出到工作区（Export to Workspace）**：

  - 当导出为工作区变量时，若 `Quantize = ON`，会在 base workspace 中写入整数向量（例如 `exported_signal`）；若 `Quantize = OFF`，会写入浮点向量（`floatY`）。
  - 可在导出后在 MATLAB 环境中直接检查/处理数据，或保存为文件以供外部工具使用。

## 已知问题与建议（TODO & Issues）

- **量化逻辑与导入源不一致**：当导入的数据为已量化的整数序列时，GUI 中与 `Quantize` 相关的控件或流程可能无法正确反映或调整原始编码参数。建议在导入时明确记录数据来源（例如在 `importedData.meta` 中保存 `origin`/`encodeType` 字段），并在 UI 中禁用或自动填充与该来源不匹配的选项。
- **文件格式兼容性不足**：CSV/文本导入可能会误读表头或包含非数值列，导致解析失败或错误提示。工程内含 `readFromCSV.m` 和 `readFromBIN.m` 工具尚未完全集成。建议统一实现一套导入辅助函数，提供：格式检测、可选跳过表头、明确的错误信息和单元测试覆盖常见文件布局。

  示例错误信息：

  ```text
  警告: SceneNode 状态错误。
  字符串标量或字符向量必须具备有效的解释器语法:
  Imported (raw): D:\\demo\\FPGA_Stimulus\\multisine_10s_48k.csv
  ```

  （附图见 `assets/issue1.png`）
- **PRBS 生成需验证**：当前实现为 MSB-first 的 Fibonacci LFSR 并支持可配置 taps，但建议补充参考向量（不同阶、不同 taps、已知 seed 下的期望输出）作为单元测试用例，以验证周期性与统计特性。
- **信号生成代码重复（signal_generator_gui 与 fxlms_gui）**：当前两者在预设信号生成、参数解析与广播逻辑上存在大量重复。建议将生成逻辑抽象为一个通用函数（例如 `generate_signal(params)` 或放在 `signal_utils` 模块中），由两个 tab 通过轻量适配层调用。实现要点：统一参数结构（type、amplitude、freq、phase、duration、fs、noise/taps 等）、明确向量/标量广播规则、返回标准化输出（float waveform、sampleRate、channels、meta），并保持向后兼容（通过 adapter 保留旧接口）。同时补充单元测试与参考向量覆盖 Sine/Square/PRBS/WhiteNoise。该重构可减少重复代码、降低维护成本并保证两个界面行为一致。但目前重复代码删除不足，且界面由于尺寸不同，存在兼容性问题。
- **图像导出能力受限**：`Save Fig` 当前仅能顺利保存 FIG 文件，PNG/ raster 导出依赖额外工具或设置。建议补充一段导出 PNG 的替代实现（例如使用 `print('-dpng',...)`）并在 README 中说明依赖。
- **依赖项与降级策略**：White Noise 的 FIR 设计依赖 Signal Processing Toolbox 的 `fir1`。若目标环境缺失该工具箱，应在启动或 README 中提示，并提供基于简单窗函数的回退实现或在导出前使用离线脚本完成滤波。
- **代码质量与维护建议**：当前存在若干静态分析警告（未用参数、未捕获的 try、单行 if/else 可读性等）。建议按模块逐步清理、添加单元测试并在关键路径加入边界输入测试。
- **数据处理灵活性不足**：如果需要对数据作简易的修改，例如时域截断、增益缩放等，都只能在工具外部实现，而不能在内部调整。

---

如有建议或需求，欢迎反馈。
