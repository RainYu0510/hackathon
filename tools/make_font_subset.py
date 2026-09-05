#!/usr/bin/env python3
"""把 Noto Sans TC 切成子集字型，供遊戲內嵌使用。

## 為什麼需要這支腳本

Godot 內建的預設字型不含中日韓字符。桌面版看起來正常，是因為 Godot 會向
作業系統的字型求援 —— Windows 上有中文字型可以 fallback。但 **Web 匯出沒有
系統字型可用**，所有中文都會變成豆腐方塊（□□□）。這個差異很誤導：桌面測
起來完全沒問題，一上 itch.io 就整個選單壞掉。

唯一的解法是把中文字型內嵌進專案。但完整的 Noto Sans TC 是 11.9 MB，對
Web 版來說太重，所以在這裡切成子集。

## 收錄範圍

1. **專案裡實際會顯示的所有非 ASCII 字元** —— 從 .tscn / .gd 的字串字面值
   掃出來。這保證目前畫面上的字一定不缺。
2. **Big5 Level 1 常用字（5401 字）** —— 用 Python 內建的 big5 codec 直接
   產生，不依賴任何外部字表檔，因此這支腳本離線也能跑、結果永遠一致。
   加這一段的目的是留餘裕：之後有人加新的中文 UI 文字，不必記得回來重跑
   這支腳本。
3. **ASCII、Latin-1 補充區、常用全角與 CJK 標點** —— 遊戲的按鈕文字是
   「開始遊戲  START GAME」這種中英並列，缺了英數字會更明顯。

## 用法

    py tools/make_font_subset.py <來源字型.ttf>

來源字型請用 SIL OFL 1.1 授權的 Noto Sans TC：
https://github.com/google/fonts/tree/main/ofl/notosanstc

輸出到 assets/fonts/NotoSansTC-Subset.ttf。

## 注意

輸出的子集**仍受 SIL OFL 1.1 約束**。OFL 允許修改與再散布（切子集屬於修
改），但必須一併散布授權條文 —— 因此 assets/fonts/NotoSansTC-OFL.txt 不要
刪掉，CREDITS.md 也要保留對應的揭露條目。
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "assets" / "fonts" / "NotoSansTC-Subset.ttf"

# 掃這些檔案裡的字串字面值。註解裡的中文不會顯示在畫面上,不需要字形。
SOURCE_GLOBS = [
    "ui/*.tscn",
    "ui/*.gd",
    "levels/*.gd",
    "autoload/*.gd",
    "interactables/*.gd",
    "actors/**/*.gd",
    "data/*.json",
]

# 全角與 CJK 標點。遊戲的副標題用到 "·",按鈕用到全角括號。
EXTRA_CHARS = (
    "　、。〈〉《》「」『』【】〔〕・…—–‧·×÷"
    "！？；：，．（）［］｛｝／＼｜～＋－＝＜＞＆％＃＠＊"
    "○●△▲□■◇◆☆★→←↑↓⇒⇐"
)


def project_chars() -> set[str]:
    """掃出專案裡所有會被顯示的非 ASCII 字元。"""
    chars: set[str] = set()
    for pattern in SOURCE_GLOBS:
        for path in ROOT.glob(pattern):
            text = path.read_text(encoding="utf-8", errors="replace")
            for line in text.splitlines():
                # 整行是 GDScript 註解就跳過;否則只取 # 之前的部分。
                stripped = line.lstrip()
                if stripped.startswith("#"):
                    continue
                code = line.split("#", 1)[0]
                for literal in re.findall(r'"([^"]*)"', code):
                    chars.update(literal)
                for literal in re.findall(r"'([^']*)'", code):
                    chars.update(literal)
    return {c for c in chars if ord(c) > 0x7F}


def big5_level1_chars() -> set[str]:
    """Big5 Level 1 常用字(0xA440-0xC67E)。

    用 Python 內建的 big5 codec 逐個 decode,所以不需要任何外部字表檔。
    Big5 的第二位元組有兩段合法區間(0x40-0x7E 與 0xA1-0xFE),不合法的組合
    decode 會丟例外,直接跳過。
    """
    chars: set[str] = set()
    for high in range(0xA4, 0xC7):
        for low in list(range(0x40, 0x7F)) + list(range(0xA1, 0xFF)):
            try:
                chars.add(bytes([high, low]).decode("big5"))
            except UnicodeDecodeError:
                continue
    return chars


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2

    source = Path(sys.argv[1])
    if not source.is_file():
        print(f"[error] 找不到來源字型:{source}")
        return 1

    try:
        from fontTools.ttLib import TTFont
        from fontTools.varLib import instancer
        from fontTools.subset import Options, Subsetter
    except ImportError:
        print("[error] 需要 fonttools:py -m pip install fonttools brotli")
        return 1

    used = project_chars()
    common = big5_level1_chars()
    ascii_range = {chr(c) for c in range(0x20, 0x7F)}
    latin1 = {chr(c) for c in range(0xA0, 0x100)}

    keep = used | common | ascii_range | latin1 | set(EXTRA_CHARS)

    print(f"[subset] 專案實際用到的非 ASCII 字元:{len(used)}")
    print(f"[subset] Big5 常用字:{len(common)}")
    print(f"[subset] 合計要保留的字元:{len(keep)}")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    font = TTFont(str(source))

    # 這是可變字型(wght 軸)。先固定成 Regular(400):遊戲沒有用到粗細變化,
    # 而保留變化軸會讓每個字形都得帶一份 delta 資料,體積差很多。
    # 這一步必須在切子集之前做 —— subset 不認得 --instancer 這種選項。
    if "fvar" in font:
        axes = {a.axisTag: (a.minValue, a.defaultValue, a.maxValue) for a in font["fvar"].axes}
        print(f"[subset] 可變字型,軸:{sorted(axes)} → 固定 wght=400")
        instancer.instantiateVariableFont(font, {"wght": 400}, inplace=True, updateFontNames=False)

    options = Options()
    options.layout_features = ["*"]  # 保留字距與字形替換,中英混排間距才正確
    options.hinting = False
    options.desubroutinize = True
    options.name_IDs = ["*"]  # 保留字型名稱與授權欄位(OFL 要求保留 Reserved Font Name)
    options.notdef_outline = True  # 缺字時畫出 .notdef 方框,比靜默消失好除錯
    options.drop_tables += ["DSIG"]
    options.recalc_bounds = True

    subsetter = Subsetter(options=options)
    subsetter.populate(unicodes=[ord(c) for c in keep])
    subsetter.subset(font)
    font.save(str(OUTPUT))
    font.close()

    size_mb = OUTPUT.stat().st_size / (1024 * 1024)
    print(f"[subset] 完成:{OUTPUT.relative_to(ROOT)}  {size_mb:.2f} MB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
