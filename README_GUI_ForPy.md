# Signal Generator GUI for Python

这是一个用于生成常见测试信号（正弦、方波、PRBS 等），预览波形并导出固定点编码采样文件的小型 Tkinter GUI 工具。

**主要文件**

- `signal_generator_gui.py`：主 GUI 脚本
- `requirements.txt`：运行所需的 Python 库（例：`numpy`, `matplotlib`）

**特性概览**

- 支持生成：正弦（Sine）、方波（Square）、伪随机二进制序列（PRBS）等
- 支持设置采样率、采样点数、振幅、偏置、相位、占空比等参数
- 可配置固定点格式（总位宽 / 小数位数，符号/无符号）
- 支持预览模拟波形与量化后波形对比
- 导出为 `.hex` / `.mem`（文本十六进制行）及 `.bin`（原始二进制）等格式

## 快速开始

1. （可选）创建并激活虚拟环境：
	```bat
	python -m venv .venv
	.venv\Scripts\activate
	```
2. 安装依赖：
	```bat
	pip install -r requirements.txt
	```
3. 运行 GUI：
	```bat
	python signal_generator_gui.py
	```

## GUI 简易说明

启动程序后，主窗口包括如下主要区域/控件：

<img src="assets\python_Interface.png" alt="MATLAB_Interface" style="zoom:50%;" />

- **Signal Type（信号类型）**：选择要生成的信号（例如 `Sine`、`Square`、`PRBS`）。
	- 选择不同类型时，右侧的参数输入会根据信号类型自动调整为相关字段。

- **Signal Parameters（信号参数）**：常见的参数有：
	- `Amplitude`（振幅）：信号的峰值幅度（模拟值）。
	- `Offset`（偏置）：在输出之前加入的直流偏移。
	- `Frequency`（频率，Hz）：信号频率（对周期信号有效）。
	- `Phase`（相位，度或弧度）：起始相位（视实现而定）。
	- `Duty`（占空比，%）：仅对方波有效，指定高电平占周期的百分比。
	- `PRBS Length / Order`：仅对 PRBS 有效，指定序列阶数或长度。
	- `Seed`（可选）：伪随机生成的种子，保证可重复性。

- **Sampling（采样设置）**：
	- `Sample Rate`（采样率，Hz）：每秒采样点数。
	- `Num Samples`（采样点数）：输出文件中包含的样本数量。

- **Fixed-point Format（固定点格式）**：
	- 顶部下拉框仅用于选择数值表示的“符号性”：`Signed` 或 `Unsigned`（下拉项不再包含具体位宽细节）。
	- `Total bits`（总位宽）和 `Fractional bits`（小数位数）在参数区中为独立可编辑字段：你可以精确指定每个样本的位宽与小数位数。
	- 当选择 `Unsigned` 时，程序会将 `Fractional bits` 设为 `0` 并暂时置为只读（避免误用），如果你需要无符号定点的分数位表示，请先切换到 `Signed` 或手动修改字段后再切换回 `Unsigned`。
	- 所有量化和导出均严格遵循 `Total bits` / `Fractional bits` 与 `Signed/Unsigned` 三者的组合设置。

- **操作按钮**：
	- `Generate & Preview`：根据当前设置生成样本并在窗口中绘制两条曲线：模拟（理想浮点）波形和量化后（固定点编码后再还原为模拟值显示）波形，以便对比。
	- `Export...`：打开导出对话框，选择导出格式（`.hex`、`.mem`、`.bin`）、文件名与保存位置。

## 核心功能：定点数格式量化

本工具将 `Signed/Unsigned`（符号位）与 `Total bits` / `Fractional bits`（位宽细节）分离管理：

- Signed/Unsigned（符号）由顶部下拉决定；Total/Fractional 由参数区指定。

- Signed 定点（Q 格式）
	- 表示方法：Qm.n（例如 Q1.15 表示 1 位符号 + 15 位小数，总 16 位）。
	- 量化（映射到整数）公式：
		- int = clip(round(x * 2^n), -2^{(total_bits-1)}, 2^{(total_bits-1)}-1)
	- 导出：带符号整数以二进制补码形式存储（`.hex`/`.mem` 为补码的十六进制表示；`.bin` 为原始字节）。

- Unsigned 定点（非负）
	- 仅表示非负范围，通常 Fractional bits 可被设置为 0（本工具在选择 `Unsigned` 时默认将其设为 0 并锁定以避免误用）。
	- 标准化量化公式（若允许 fractional>0，可按下式）：
		- int = round((x - x_min) / (x_max - x_min) * (2^{total_bits}-1))
	- 导出：按无符号整数直接存储（`.hex`/`.mem` 为十六进制文本；`.bin` 为原始字节）。

注意事项：

- 在 `Unsigned` 模式下，若你的信号包含负值，请先将信号偏移为非负，否则量化会截断或产生不正确的映射。
- `Fractional bits` 决定量化精度；`Total bits` 决定动态范围（包括符号位）。通常 Signed 的默认小数位可取 `Total bits - 1`，以获得较大精度而牺牲整数范围。

所有导出格式（`.hex` / `.mem` / `.bin`）均严格按当前三项设置（Signed/Unsigned + Total bits + Fractional bits）输出，建议在导出前在 Preview 中确认量化效果与数值范围。

## 预览窗口说明

预览窗口通常显示两条曲线：

- **Analog / Float**：理想连续（浮点）信号，用于参考。
- **Quantized / Fixed-point**：对理想信号按指定固定点格式量化后的结果，显示量化误差与饱和情况。

观察点：如果量化小数位数太少或总位宽不足，量化误差或溢出（饱和）将很明显。
并且预览窗口现在支持交互式操作，类似 MATLAB Figure：

- **工具栏（Pan/Zoom）**：图像上方有 matplotlib 的导航工具栏，包含放大、平移、重置（Home）等按钮。点击 `Pan` 按钮后可用鼠标拖动图像进行平移。
- **滚轮缩放**：将鼠标移动到图像区域并滚动鼠标滚轮可以实现以鼠标位置为中心的放大/缩小。
- **矩形缩放**：在图像上按住左键并拖动可以画选框，释放后会把坐标轴限制到选框范围（局部放大）。
- **重置视图**：使用工具栏上的 `Home` 按钮可以恢复到生成时的默认视图。

这些交互控件无需额外配置（只要已安装 `matplotlib` 且使用 `TkAgg` 后端），在交互式操作时会即时刷新预览，便于观察量化误差、饱和与波形细节。

## UI 模式说明

下面按界面中的“模式/信号类型”逐章说明每个核心功能及其相关子功能、参数与使用建议。每章包含：参数（Parameters）、使用示例（Usage）和小提示（Tips）。

### Signal Generation 信号生成类型

#### （1）Sine（正弦波）

- **Parameters:** `Amplitude`, `Offset`, `Frequency`, `Phase`, `Sample Rate`, `Num Samples`, `Total bits`, `Fractional bits`, `Signed/Unsigned`。
- **Usage:** 输入频率与采样率，建议确保 `Sample Rate` 至少为信号频率的 10 倍以便在预览中观察连续形态；点击 `Generate & Preview` 查看模拟与量化后的对比。
- **Tips:** 相位单位视 UI 显示（度或弧度），在导出为定点时注意 `Amplitude` 与 `Offset` 的组合不要造成溢出；可先在 Preview 中将 Y 轴放大检查峰值。

#### （2）Square（方波）
- **Parameters:** `Amplitude`, `Offset`, `Frequency`, `Duty`（占空比）, `Phase`, `Sample Rate`, `Num Samples`, 固定点参数同上。
- **Usage:** 方波对位宽敏感，低 `Total bits` 会导致阶跃明显变形；占空比用于控制高电平占比（0-100%）。
- **Tips:** 导出为无符号格式时，先将 `Offset` 调整为非负以避免截断；若目标设备期望 PWM 风格的采样（0/1），请将 `Total bits` 设置为 1 或后处理为二值化。

#### （3）PRBS（伪随机二进制序列）
- **Parameters:** `Mode`（LFSR / RNG）、`Order`（LFSR 阶数，如 7/15/31）、`Seed`、`Amplitude`、`Offset`、`Sample Rate`, `Num Samples`，固定点参数。
- **Usage:**
	- 当选择 LFSR 模式时，请设置 `Order` 与 `Seed` 以保证序列的可重复性与长度（例如 Order=7 的最大周期为 2^7-1）。
	- 生成时，程序会以阶梯（stairs）方式绘制模拟曲线以便观察离散跳变。
	- 若选择 RNG（伪随机）模式，仅需 `Seed`（可选），程序生成均匀/二值随机样本。
- **Tips:**
	- PRBS 通常用于测试链路抖动、误码率和均衡器；对于 FPGA 则常导出为宽位二进制（例如 1-bit 序列或 N-bit 映射）。
	- 导出二进制文件时注意端点对齐（字节边界）。

### Sampling / Time（采样设置与时长）
- **Parameters:** `Sample Rate`, `Num Samples`, `Time`（秒）——在 UI 中三者联动，编辑其中任意两个会自动计算第三项。
- **Usage:**
	- 若希望固定总时长，设置 `Time` 与 `Sample Rate`，程序会计算 `Num Samples = Time * Sample Rate`（向下取整）。
	- 若需要精确样本点数以匹配硬件缓冲区，直接设置 `Num Samples` 与 `Sample Rate`，`Time` 会自动更新。
- **Tips:** 在更改参数时请留意四舍五入与整数取样导致的微小时间偏差；导出前确认生成的样本数与目标设备一致。

### Preview / Interaction（预览与交互）
- **Parameters/Controls:** Matplotlib 工具栏、滚轮缩放、矩形框选。
- **Usage:**
	- 使用工具栏的 `Pan`/`Zoom` 按钮进行平移与缩放；在图上滚轮缩放会以鼠标位置为中心放大/缩小；左键拖动矩形框选后会放大到选区。
	- `Generate & Preview` 后，默认会显示 `Analog / Float` 与 `Quantized / Fixed-point` 两条曲线；对于 PRBS，模拟曲线以阶梯展示。
- **Tips:**
	- 若图像空白或无法交互，请确认 matplotlib 安装且后端为 `TkAgg`；在远程桌面/无图形环境下可能无法使用交互功能。

## 定点格式选项 Fixed-point Format
- **Parameters:** 顶部 `Signed/Unsigned`，以及参数区的 `Total bits` 与 `Fractional bits`。
- **Usage:**
	- 选择 `Signed` 时采用 Q 格式（两补码），`Fractional bits` 决定小数精度；选择 `Unsigned` 时程序默认将 `Fractional bits` 置为 0（可临时改回但需谨慎）。
	- 在导入已有样本时，请确保填写与生成时一致的 `Total bits`/`Fractional bits`/符号性以便正确重建浮点值。
- **Tips:**
	- 若信号包含负值请使用 `Signed`，或将信号偏移为非负再选择 `Unsigned`。
	- 导出后在目标环境中解析时务必使用相同的位宽与补码规则。

## 导出与导入 Export / Import
- **Export:** 支持 `.hex`、`.mem`（文本十六进制行）与 `.bin`（原始二进制）。导出选项会使用当前的固定点设定（Total/Fractional/Signed）将样本转换为整数并写入文件。
- **Import:** 新增的 `Import...` 对话框支持载入已导出的 `.hex`/`.mem`/`.bin`，需要用户提供 `Total bits`/`Fractional bits`/Signed 与（对 Unsigned）`vmin`/`vmax` 用于重建浮点数据。导入时程序会校验样本位宽与文件长度的一致性，并在预览窗口显示导入结果。
- **Tips:**
	- 导入流程要求用户确认位宽与符号性；若不确定，建议先用导出示例对照或使用小样本文件进行验证。

### 导出格式说明

程序支持以下几类导出格式：

- `.hex`：文本格式，每行一个样本的十六进制表示（默认大端顺序的按位表示），适用于许多 FPGA/嵌入式工具链。
- `.mem`：类似 `.hex`，是按行的十六进制文本，常用于模拟器或 IP Core 初始化内存文件（纯文本十六进制）。
- `.bin`：原始二进制文件，按样本的二进制表示顺序写入（注意字节序与位宽对接收端的要求）。

导出注意事项：

- 对于**带符号**数据，负值会被转换为二进制补码表示写入文件。
- 对于 `.bin`，请确认对端对于**字节序（Endianness）**的期望（本工具通常按平台字节序输出，若需要特定字节序请在导出选项里检查或后处理）。
- `.hex` / `.mem` 的每一行为一个样本的完整位宽值（无前缀），例如 16 位样本：`FFEE`。

示例：将 16-bit 有符号数据导出为 `.hex`，文件内容可能如下：

```
7FFF
4000
0000
C000
8001
```

（表示若干 16 位样本的十六进制两字节表示）

## 常见问题与排查

- 无法显示预览图：请确认已安装 `matplotlib`，并在 GUI 中未禁用弹窗。可在命令行运行 `python -c "import matplotlib"` 检查是否可用。
- 导出后文件格式与目标不兼容：检查目标工具/模块期望的位宽、字节序和数值表示（有无符号）。可以通过导出 `.bin` 后用小脚本读取并验证字节顺序。
- 量化误差过大：尝试增加 `Total bits` 或 `Fractional bits`，或减少信号振幅/偏移以避免饱和。

## 扩展与贡献

如果需要添加更多导出格式（如 MIF、COE）、固定点预设或批处理/命令行生成接口，我可以协助实现。欢迎提交 issue/PR 或直接在本仓库中修改并测试。

## 版权与许可

请根据项目整体许可证使用或分发本工具（本仓库未在此文件内指定许可证）。

----

如果你希望我把文档保留为英文版或提供双语（中/英）说明，也可以告诉我，我会把两种语言都放进 `README_GUI.md`。另外，如果要我直接在导出对话框中添加特定字节序或 MIF/COE 的导出选项，也可以继续指示。 
