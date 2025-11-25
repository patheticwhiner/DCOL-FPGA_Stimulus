# 固定滤波器ANC实验

研究固定滤波器实验是我们探究ANC实验的基础。

当前MATLAB工具被用以生成实验数据，探究辨识模型及其所能取得的最优性能。

实验对主次通路均采取长度为512的FIR模型，并生成不同频段的reference noise，分别进行实验并验证实验效果，为后续的实验奠定一定的crude work基础。
推荐的噪声文件命名规范如下：
```
[噪声类型]_[频段下限]T[频段上限]Hz_Fs[采样率]_[滤波器类型]Order[阶数]_[日期].bin
```
```
窄带噪声：
    200,400,600Hz    → Harmonic_Base200_Fs48kHz_FIROrder512_Q123.bin
    300,600,900Hz    → Harmonic_Base300_Fs48kHz_FIROrder512_Q123.bin
    400,800,1200Hz   → Harmonic_Base400_Fs48kHz_FIROrder512_Q123.bin
    500,1000,1500Hz  → Harmonic_Base500_Fs48kHz_FIROrder512_Q123.bin
宽带噪声：
    200~300Hz    → BB_200T300Hz_Fs48kHz_FIROrder512_Q123.bin
    200~500Hz    → BB_200T500Hz_Fs48kHz_FIROrder512_Q123.bin
    200~1000Hz   → BB_200T1000Hz_Fs48kHz_FIROrder512_Q123.bin
    500~600Hz    → BB_500T600Hz_Fs48kHz_FIROrder512_Q123.bin
    500~800Hz    → BB_500T800Hz_Fs48kHz_FIROrder512_Q123.bin
    500~1000Hz   → BB_500T1000Hz_Fs48kHz_FIROrder512_Q123.bin
宽频噪声：
    200~2000Hz   → WB_200T2000Hz_Fs48kHz_FIROrder512_Q123.bin
环境噪声：
    电路板电磁电流噪声 → ENV_ElecBoardEMI_Fs48kHz_Q123.bin
    发电机噪声         → ENV_Generator_Fs48kHz_Q123.bin
    风扇噪声           → ENV_Fan_Fs48kHz_Q123.bin
    教室吵闹声         → ENV_Classroom_Fs48kHz_Q123.bin
    拖拉机噪声         → ENV_Tractor_Fs48kHz_Q123.bin
```

## 单频测试



## 谐波测试

### 200

完全失败，没有起到任何降噪的效果，甚至噪声更大了。

## 宽带噪声测试

