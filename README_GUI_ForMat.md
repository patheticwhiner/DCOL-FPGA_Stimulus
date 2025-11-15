# Signal Generator GUI for MATLAB

## 简介

`signal_generator_gui.m` 是一个 MATLAB 图形界面工具，可用于生成 Sine（正弦）、Square（方波）、PRBS（伪随机序列）信号，并支持多种定点编码格式导出为 FPGA/数字系统常用文件。

## 功能特性

![MATLAB_Interface](assets\MATLAB_Interface.png)

- 支持信号类型：Sine、Square、PRBS
- 动态显示信号参数（如幅值、频率、相位、时长、采样率等）
- 支持定点编码格式：
  - Signed Q (N bits, frac bits)
  - Signed Two's complement (N bits)
  - Unsigned (N bits)
- 支持导出格式：
  - `.hex`、`.mem`（每行一个十六进制数，文本格式）
  - `.bin`（原始字节流，按大端序，每样本 `ceil(Nbits/8)` 字节）
  - 可扩展支持 `.csv`、Vivado COE、MIF 等格式
- 支持导入已有数据文件进行预览和再导出
- 预览区可显示生成或导入的信号波形

## 使用方法

1. 打开 MATLAB，将 `d:/demo/FPGA_Stimulus` 文件夹添加到路径或切换到该目录。
2. 在命令行运行：

   ```matlab
   signal_generator_gui
   ```

3. 在 GUI 中选择信号类型、设置参数，点击 `Generate & Preview` 预览/覆盖上个信号。
4. 可选择导入已有数据文件（支持 `.hex`、`.mem`、`.bin`、`.coe`、`.mif`、`.csv`）。
5. 点击 `Export...` 导出当前信号或导入数据。

## 编码与导出说明

### 编码格式说明
- **Q-format**：信号按 `2^frac` 放大并四舍五入，超出范围自动截断。
- **Unsigned / Signed Two's complement**：信号先归一化到 [-1, 1]，再量化为定点整数。

### 导出格式说明
- **.hex / .mem**：每行一个十六进制数，自动补零到所需位宽。
- **.bin**：每个样本按大端序写入，字节数为 `ceil(Nbits/8)`。
- **导入数据**：支持多种格式，导入后可直接预览和导出。

## 扩展建议

- 脚本不依赖 MATLAB 工具箱，兼容性好.
- PRBS 生成器为简单 LFSR，可在参数区自定义 taps。
- 生成信号后再次导出时，优先使用最新生成的数据。
- 可增加 `.bin` 小端序选项
- 支持更多导出格式（如 Vivado COE、CSV、MIF）
- 优化 PRBS taps 参数输入体验

---

如有建议或需求，欢迎反馈。