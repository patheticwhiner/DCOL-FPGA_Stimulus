import os

# 源目录
img_dir = os.path.join(os.path.dirname(__file__), "image", "fixed_FIR")

# 原始文件名与新文件名映射
rename_map = {
    "1764162612431.png": "fixedFIR_sine_200Hz.png",
    "1764163948400.png": "fixedFIR_harmonic_200Hz.png",
    "1764164196989.png": "fixedFIR_harmonic_300Hz.png",
    "1764164271047.png": "fixedFIR_harmonic_400Hz.png",
    "1764164026891.png": "fixedFIR_harmonic_500Hz.png",
    "1764159358542.png": "fixedFIR_BB_200T300Hz.png",
    "1764159887550.png": "fixedFIR_BB_200T500Hz.png",
    "1764160030603.png": "fixedFIR_BB_200T1000Hz.png",
    "1764158074683.png": "fixedFIR_BB_300T500Hz.png",
    "1764158944721.png": "fixedFIR_BB_300T700Hz.png",
    "1764160244199.png": "fixedFIR_BB_500T600Hz.png",
    "1764160353082.png": "fixedFIR_BB_500T800Hz.png",
    "1764160449165.png": "fixedFIR_BB_500T1000Hz.png",
    "1764160652546.png": "fixedFIR_WB_200T2000Hz.png"
}

for old_name, new_name in rename_map.items():
    old_path = os.path.join(img_dir, old_name)
    new_path = os.path.join(img_dir, new_name)
    if os.path.exists(old_path):
        os.rename(old_path, new_path)
        print(f"Renamed: {old_name} -> {new_name}")
    else:
        print(f"File not found: {old_name}")
