#!/usr/bin/env python3
"""把 AI 產出的接觸表(contact sheet)切成 Godot 能用的精靈圖 strip。

輸入是一張「一排角色動作」的圖,輸出是等格、腳底對齊、已去背、已降到目標
解析度的橫向 strip,外加一張放大預覽圖給人眼驗收。

為什麼不用 Aseprite / ImageMagick:Aseprite 的 Import Sprite Sheet 假設你已經
有等距網格,而 AI 算出來的接觸表格距不均、有編號列、腳底基準線不齊。這幾件事
得先做完,才輪得到那類工具。這支腳本做的就是「先做完」的部分。

三個非顯而易見的處理,每個都對應一個實際踩到的坑:

  1. 去背只移除「與畫布邊緣相連」的暗像素。角色是黑貓、背景也是黑的,
     `亮度 < 門檻 → 透明` 會把貓的身體整個吃掉。
  2. 降取樣前必須 premultiply alpha。不做的話透明的黑背景會混進角色邊緣,
     整圈長出深色鑲邊。
  3. 腳下那條地面陰影橫條要剝掉。它跟角色是分離的,但用 bbox 找不出來 ——
     靠「fg 寬度在某一列突然暴增」這個特徵切。

沒有原生像素網格可以還原:來源是帶抗鋸齒的「偽像素風」算圖,水平 run-length
的 GCD = 1。所以降取樣是 box filter + alpha 二值化,不是 nearest-neighbor。

只用 stdlib + numpy,不需要 Pillow。

用法(Windows 上 `python` 可能是 Microsoft Store 的 stub,用 `py`):

    py tools/make_spritesheet.py art/source/cat_run_sheet.png --out art/player/cat_run

常用開關:

    --height 32          角色目標高度(art px),預設 22
    --keep-shadow        保留地面陰影橫條
    --align-x none       不做水平對齊(來源已置中時比 center 更穩)
    --godot-frames P     順便產出 SpriteFrames .tres 給 AnimatedSprite2D
"""

import argparse
import json
import struct
import sys
import zlib
from collections import deque
from pathlib import Path

import numpy as np

# --------------------------------------------------------------------------
# PNG I/O
# --------------------------------------------------------------------------
#
# 自己寫而不是裝 Pillow:讀寫都只需要 zlib + 一段 unfilter,加起來不到一百行,
# 換來這支腳本在任何有 numpy 的環境都能直接跑。


def read_png(path: Path) -> np.ndarray:
    """讀 8-bit non-interlaced PNG,一律回傳 (h, w, 4) 的 RGBA uint8。"""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} 不是 PNG")

    pos = 8
    idat = bytearray()
    width = height = bit_depth = color_type = interlace = None
    palette = None
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos : pos + 4])
        chunk_type = data[pos + 4 : pos + 8]
        body = data[pos + 8 : pos + 8 + length]
        pos += 12 + length  # 4 長度 + 4 型別 + body + 4 CRC
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", body[:13]
            )
        elif chunk_type == b"PLTE":
            palette = np.frombuffer(body, dtype=np.uint8).reshape(-1, 3)
        elif chunk_type == b"IDAT":
            idat += body
        elif chunk_type == b"IEND":
            break

    # 這些限制都是刻意不支援而不是忘了寫 —— 來源是 AI 算圖,不會是 16-bit 或
    # interlaced。真的遇到就會在這裡明確爆掉,而不是靜默算出一張壞圖。
    if bit_depth != 8:
        raise ValueError(f"{path}: 只支援 8-bit,這張是 {bit_depth}-bit")
    if interlace != 0:
        raise ValueError(f"{path}: 不支援 interlaced PNG")
    if color_type not in (2, 3, 6):
        raise ValueError(f"{path}: 不支援 color type {color_type}(只支援 2/3/6)")

    channels = {2: 3, 3: 1, 6: 4}[color_type]
    raw = _unfilter(zlib.decompress(idat), width, height, channels)
    pixels = raw.reshape(height, width, channels)

    if color_type == 3:
        if palette is None:
            raise ValueError(f"{path}: color type 3 但沒有 PLTE chunk")
        pixels = palette[pixels[..., 0]]
        channels = 3
    if channels == 3:
        alpha = np.full((height, width, 1), 255, np.uint8)
        pixels = np.concatenate([pixels, alpha], axis=2)
    return np.ascontiguousarray(pixels)


def _unfilter(raw: bytes, width: int, height: int, channels: int) -> np.ndarray:
    """逐列還原 PNG 的五種 filter。

    Sub / Average / Paeth 在 x 方向是遞迴的,沒辦法向量化,所以走純 Python 的
    bytearray 迴圈 —— 對這個尺寸的圖只要一兩秒,不值得為它引入相依。
    None / Up 走 numpy。
    """
    stride = width * channels
    out = bytearray(height * stride)
    prev = bytearray(stride)
    src = 0
    dst = 0
    for _ in range(height):
        ftype = raw[src]
        src += 1
        line = bytearray(raw[src : src + stride])
        src += stride

        if ftype == 0:
            pass
        elif ftype == 1:  # Sub
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif ftype == 2:  # Up
            np_line = np.frombuffer(bytes(line), np.uint8) + np.frombuffer(
                bytes(prev), np.uint8
            )
            line = bytearray(np_line.tobytes())
        elif ftype == 3:  # Average
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif ftype == 4:  # Paeth
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        else:
            raise ValueError(f"未知的 PNG filter type {ftype}")

        out[dst : dst + stride] = line
        dst += stride
        prev = line
    return np.frombuffer(bytes(out), np.uint8)


def write_png(path: Path, rgba: np.ndarray) -> None:
    """寫 8-bit RGBA PNG。一律用 filter type 0 —— 這些圖很小,壓縮率不是問題。"""
    height, width = rgba.shape[:2]
    rows = np.concatenate(
        [np.zeros((height, 1), np.uint8), rgba.reshape(height, -1)], axis=1
    )
    payload = zlib.compress(rows.tobytes(), 9)

    def chunk(tag: bytes, body: bytes) -> bytes:
        return (
            struct.pack(">I", len(body))
            + tag
            + body
            + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)
        )

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", payload)
        + chunk(b"IEND", b"")
    )


# --------------------------------------------------------------------------
# 分析
# --------------------------------------------------------------------------


def _row_runs(mask_row: np.ndarray) -> list[tuple[int, int]]:
    """把一列布林值切成 [(x0, x1_inclusive), ...] 的 True 區段。"""
    padded = np.concatenate([[False], mask_row, [False]])
    edges = np.diff(padded.astype(np.int8))
    starts = np.flatnonzero(edges == 1)
    ends = np.flatnonzero(edges == -1) - 1
    return list(zip(starts.tolist(), ends.tolist()))


def background_mask(rgba: np.ndarray, threshold: int) -> tuple[np.ndarray, list[int]]:
    """回傳 (背景遮罩, 未被觸及的暗區面積列表)。

    只把「暗且與畫布邊緣相連」的像素當背景。用 run 為單位做 BFS 而不是逐像素:
    每列的暗區段通常只有個位數,幾千個 run 的圖搜起來是瞬間的事,逐像素則要跑
    幾十萬次迴圈。
    """
    lum = rgba[..., :3].max(axis=2)
    dark = lum <= threshold
    height, width = dark.shape

    runs: list[list[tuple[int, int]]] = [_row_runs(dark[y]) for y in range(height)]
    index: dict[tuple[int, int], int] = {}
    flat: list[tuple[int, int, int]] = []  # (y, x0, x1)
    for y, row in enumerate(runs):
        for i, (x0, x1) in enumerate(row):
            index[(y, i)] = len(flat)
            flat.append((y, x0, x1))

    def neighbours(y: int, i: int):
        _, x0, x1 = flat[index[(y, i)]]
        for ny in (y - 1, y + 1):
            if 0 <= ny < height:
                for j, (nx0, nx1) in enumerate(runs[ny]):
                    if nx0 <= x1 and nx1 >= x0:  # x 區間重疊 = 4-連通
                        yield (ny, j)

    seeds = [
        (y, i)
        for y, row in enumerate(runs)
        for i, (x0, x1) in enumerate(row)
        if y in (0, height - 1) or x0 == 0 or x1 == width - 1
    ]

    seen: set[tuple[int, int]] = set(seeds)
    queue = deque(seeds)
    while queue:
        node = queue.popleft()
        for nxt in neighbours(*node):
            if nxt not in seen:
                seen.add(nxt)
                queue.append(nxt)

    bg = np.zeros_like(dark)
    for y, i in seen:
        _, x0, x1 = flat[index[(y, i)]]
        bg[y, x0 : x1 + 1] = True

    # 沒被觸及的暗區 = 被角色包圍的封閉暗塊。對黑貓來說多半真的是身體,所以
    # 不自動填,只回報面積讓人判斷。
    trapped = _component_sizes(dark & ~bg)
    return bg, trapped


def _component_sizes(mask: np.ndarray) -> list[int]:
    """回傳各連通區塊的面積,由大到小。同樣走 run BFS。"""
    height = mask.shape[0]
    runs = [_row_runs(mask[y]) for y in range(height)]
    seen: set[tuple[int, int]] = set()
    sizes: list[int] = []
    for y in range(height):
        for i in range(len(runs[y])):
            if (y, i) in seen:
                continue
            seen.add((y, i))
            queue = deque([(y, i)])
            area = 0
            while queue:
                cy, ci = queue.popleft()
                cx0, cx1 = runs[cy][ci]
                area += cx1 - cx0 + 1
                for ny in (cy - 1, cy + 1):
                    if 0 <= ny < height:
                        for nj, (nx0, nx1) in enumerate(runs[ny]):
                            if nx0 <= cx1 and nx1 >= cx0 and (ny, nj) not in seen:
                                seen.add((ny, nj))
                                queue.append((ny, nj))
            sizes.append(area)
    return sorted(sizes, reverse=True)


def _runs_1d(flags: np.ndarray) -> list[tuple[int, int]]:
    return _row_runs(flags)


def pick_band(fg: np.ndarray, band_index: int | None) -> tuple[int, int]:
    """找角色所在的橫帶,把編號標籤列排除掉。

    做法是找「至少有一個 fg 像素的連續列區段」。只有一段就是沒有標籤列;
    多段時預設取最上面那段 —— 接觸表的慣例是角色在上、標籤在下。
    """
    bands = _runs_1d(fg.any(axis=1))
    if not bands:
        raise ValueError("整張圖都被判成背景,把 --bg-threshold 調低試試")
    if band_index is not None:
        return bands[band_index]
    return bands[0]


def split_columns(fg: np.ndarray, frames: int) -> tuple[list[tuple[int, int]], str]:
    """把橫帶切成每格一塊。回傳 (區段列表, 用了哪個模式)。

    等距優先:能整除又剛好每格一塊 fg 就用等分,因為等分不受「相鄰兩格的手腳
    幾乎碰在一起」影響。切不出來才退回看空隙投影。
    """
    width = fg.shape[1]
    if width % frames == 0:
        cell = width // frames
        cuts = [(i * cell, (i + 1) * cell - 1) for i in range(frames)]
        if all(fg[:, a : b + 1].any() for a, b in cuts):
            return cuts, f"等距網格({frames} × {cell}px)"

    spans = _runs_1d(fg.any(axis=0))
    if len(spans) != frames:
        raise ValueError(
            f"投影切格切出 {len(spans)} 塊,但 --frames 是 {frames}。"
            f"各塊寬度:{[b - a + 1 for a, b in spans]}"
        )
    return spans, f"空隙投影({frames} 塊)"


def row_widths(cell_fg: np.ndarray) -> np.ndarray:
    """每一列的 fg 橫向跨距(最右 - 最左 + 1),空列為 0。"""
    widths = np.zeros(cell_fg.shape[0], int)
    for y in range(cell_fg.shape[0]):
        xs = np.flatnonzero(cell_fg[y])
        if xs.size:
            widths[y] = int(xs[-1] - xs[0]) + 1
    return widths


def find_ground_line(widths: np.ndarray, cut_ratio: float) -> int | None:
    """找地面陰影帶的頂端列,回傳該列(它與以下全部丟掉);找不到回傳 None。

    **跨格一起判,不逐格判。** 陰影是共同的地平線,在每一格都落在同樣的列 ——
    實測 8 格的陰影全都在 local y=294..301。逐格判會被兩件事騙倒:格 7 的揚塵
    特效跟陰影一樣寬(118-120px),格 1 底部有 5px 的殘屑。

    判準是「跨格中位數寬度」。中位數對上面兩種個案都免疫,也對格 4/5 抬腳騰空
    (那幾列寬度是 0)免疫。實測中位數在 y=293 是 10、y=294 跳到 106,一個數量級
    的落差,門檻放在最大值的 50% 綽綽有餘。

    widths: (frames, rows) 的寬度表。
    """
    median = np.median(widths, axis=0)
    if median.max() <= 0:
        return None
    wide = median >= median.max() * cut_ratio
    runs = _runs_1d(wide)
    if not runs:
        return None
    top, _ = runs[-1]  # 最底下那段連續寬帶
    # 整張圖只有一段寬帶 = 那是角色本體不是陰影(例如已經去過陰影的來源)。
    return int(top) if len(runs) > 1 or top > len(median) * 0.5 else None


def despeckle(rgba: np.ndarray, min_blob: int) -> tuple[np.ndarray, list[tuple[int, int, int]]]:
    """刪掉面積小於 min_blob 的孤立不透明區塊,回傳 (結果, 刪掉幾塊)。

    13 倍降取樣之後,尾巴尖端、揚塵、抗鋸齒殘留會變成一兩顆飄在角色旁邊的
    浮空像素。它們在放大預覽裡非常顯眼,而且動起來會閃。
    """
    if min_blob <= 1:
        return rgba, []
    solid = rgba[..., 3] > 0
    height = solid.shape[0]
    runs = [_row_runs(solid[y]) for y in range(height)]
    seen: set[tuple[int, int]] = set()
    removed: list[tuple[int, int, int]] = []
    out = rgba.copy()
    for y in range(height):
        for i in range(len(runs[y])):
            if (y, i) in seen:
                continue
            seen.add((y, i))
            queue = deque([(y, i)])
            members = []
            while queue:
                cy, ci = queue.popleft()
                members.append((cy, ci))
                cx0, cx1 = runs[cy][ci]
                for ny in (cy - 1, cy + 1):
                    if 0 <= ny < height:
                        for nj, (nx0, nx1) in enumerate(runs[ny]):
                            if nx0 <= cx1 and nx1 >= cx0 and (ny, nj) not in seen:
                                seen.add((ny, nj))
                                queue.append((ny, nj))
            area = sum(runs[cy][ci][1] - runs[cy][ci][0] + 1 for cy, ci in members)
            if area < min_blob:
                for cy, ci in members:
                    cx0, cx1 = runs[cy][ci]
                    out[cy, cx0 : cx1 + 1] = 0
                # 記位置不只記數量:光看「刪了 12 塊」分不出那是雜訊還是
                # 尾巴尖端。這次就是被這行字騙過去的。
                removed.append((runs[y][i][0], y, area))
    return out, removed


# --------------------------------------------------------------------------
# 去背門檻的自動推導與角色完整性健檢
# --------------------------------------------------------------------------

# 探測用的極保守門檻。先用它把橫帶與切格算出來:這兩件事只需要知道「角色
# 大致在哪」,對門檻極不敏感,而門檻掃描需要固定的格邊界才能互相比較。
PROBE_THRESHOLD = 2

# 掃描的門檻階梯。上界 34 是因為再高連角色亮部都會被吃掉,沒有討論價值。
BG_LADDER = (2, 4, 6, 8, 10, 12, 16, 20, 26, 34)

# 「主連通塊要佔角色多少比例」才算沒被切碎。角色理論上是少數幾塊
# (身體 + 可能分離的尾巴或手),主體應該佔絕大多數。
INTEGRITY_TARGET = 0.90


def frame_integrity(
    band_fg: np.ndarray, spans: list[tuple[int, int]]
) -> list[tuple[int, float]]:
    """逐格回傳 (連通區塊數, 主區塊佔前景面積的比例)。

    **這是這支工具最重要的健檢,因為面積類指標偵測不到它要抓的問題。**
    前景百分比在「角色完好」與「角色被切成 30 塊」兩種情況下看起來一樣合理 ——
    面積對了,拓樸壞了。

    實際踩過:門檻 20 時前景 33.5%(看起來完全正常),但主區塊只佔 33-60%。
    這張圖的角色有黑色描邊,描邊亮度跟背景一樣,flood fill 把描邊當成通道
    鑽進角色內部,頭跟身體被切開,尾巴與手臂散架。
    """
    out: list[tuple[int, float]] = []
    for x0, x1 in spans:
        areas = _component_sizes(band_fg[:, x0 : x1 + 1])
        total = sum(areas)
        out.append((len(areas), areas[0] / total if total else 0.0))
    return out


def integrity_verdict(fraction: float) -> str:
    """把主區塊佔比翻成判準。只印數字不印判準等於沒印 ——
    讀的人不知道多少算不正常,就會直接跳過那一行。"""
    if fraction >= INTEGRITY_TARGET:
        return "OK"
    if fraction >= 0.70:
        return "注意"
    return "!! 角色被切碎"


def choose_bg_threshold(
    sheet: np.ndarray,
    top: int,
    bottom: int,
    spans: list[tuple[int, int]],
    target: float = INTEGRITY_TARGET,
) -> tuple[int, list[tuple[int, float, float, int]], bool]:
    """掃描門檻階梯,挑出「角色還完整」的最大門檻。

    回傳 (選中的門檻, 掃描表, 是否有門檻達標)。掃描表每列是
    (門檻, 前景比例, 最差的主區塊佔比, 最多的區塊數)。

    為什麼要自動推而不寫死一個數字:這個值完全取決於來源圖怎麼畫。這張黑貓
    用黑色線條描邊,門檻越過 8 就會讓背景沿著描邊鑽進角色。換一張沒有描邊、
    或背景不是純黑的來源,臨界點會完全不同 —— 寫死的魔術數字換張圖就會再爆
    一次,而且爆得很安靜(畫面怪怪的,但沒有任何錯誤訊息)。

    取「最大的仍達標門檻」而不是最小的:門檻越低,留在角色周圍的背景暈影
    越多,輪廓會虛胖。要的是崩塌轉折點以下、但盡量靠近它的那個值。
    """
    rows: list[tuple[int, float, float, int]] = []
    for thr in BG_LADDER:
        fg = ~background_mask(sheet, thr)[0]
        stats = frame_integrity(fg[top : bottom + 1], spans)
        rows.append(
            (thr, float(fg.mean()),
             min(f for _, f in stats),
             max(c for c, _ in stats))
        )
    passing = [r for r in rows if r[2] >= target]
    if passing:
        return max(passing, key=lambda r: r[0])[0], rows, True
    # 沒有任何門檻達標 = 來源本身有問題(背景不是純黑、角色與背景同色…)。
    # 挑最好的繼續跑,但要讓使用者知道這張圖需要人去看。
    return max(rows, key=lambda r: r[2])[0], rows, False

# --------------------------------------------------------------------------
# 影像處理
# --------------------------------------------------------------------------


def box_weights(src_len: int, dst_len: int) -> np.ndarray:
    """一維 box filter 的權重矩陣 (dst_len, src_len),每列和為 1。

    直接算面積重疊而不是先放大到公倍數再平均 —— 縮放比是 13 倍多的非整數,
    公倍數法會吃掉大量記憶體而且結果一樣。
    """
    scale = src_len / dst_len
    weights = np.zeros((dst_len, src_len))
    for i in range(dst_len):
        lo, hi = i * scale, (i + 1) * scale
        first, last = int(np.floor(lo)), min(int(np.ceil(hi)), src_len)
        for j in range(first, last):
            weights[i, j] = max(0.0, min(hi, j + 1) - max(lo, j))
    total = weights.sum(axis=1, keepdims=True)
    return weights / np.where(total == 0, 1, total)


def downscale(cell: np.ndarray, out_h: int, out_w: int, alpha_cutoff: float) -> np.ndarray:
    """premultiplied box filter + alpha 二值化。

    premultiply 是硬需求:透明區的 RGB 是純黑,直接平均會把黑色混進角色邊緣,
    整圈長出深色鑲邊。算完再用「連續的」alpha 還原 RGB —— 用二值化後的 alpha
    還原會把半透明邊緣的顏色算錯。
    """
    src = cell.astype(np.float64)
    alpha = src[..., 3:4] / 255.0
    premult = np.concatenate([src[..., :3] * alpha, alpha], axis=2)

    wy = box_weights(cell.shape[0], out_h)
    wx = box_weights(cell.shape[1], out_w)
    tmp = np.tensordot(wy, premult, axes=([1], [0]))          # (out_h, w, 4)
    small = np.tensordot(tmp, wx, axes=([1], [1]))            # (out_h, 4, out_w)
    small = np.transpose(small, (0, 2, 1))                    # (out_h, out_w, 4)

    a = small[..., 3:4]
    rgb = np.divide(small[..., :3], a, out=np.zeros_like(small[..., :3]), where=a > 1e-6)
    solid = (a[..., 0] >= alpha_cutoff)
    out = np.zeros((out_h, out_w, 4), np.uint8)
    out[..., :3] = np.clip(np.rint(rgb), 0, 255).astype(np.uint8)
    out[..., 3] = np.where(solid, 255, 0)
    out[~solid] = 0  # 透明像素的 RGB 歸零,避免殘留顏色影響之後的縮放
    return out


def make_preview(strip: np.ndarray, cell_w: int, zoom: int = 8) -> np.ndarray:
    """放大 + 洋紅底 + 格線。洋紅是因為它絕不會出現在這隻黑貓身上,
    所以「哪裡沒去乾淨」一眼就看得出來。"""
    big = np.repeat(np.repeat(strip, zoom, axis=0), zoom, axis=1)
    canvas = np.zeros((*big.shape[:2], 4), np.uint8)
    canvas[..., :] = (255, 0, 255, 255)
    solid = big[..., 3] > 0
    canvas[solid] = big[solid]
    for i in range(1, strip.shape[1] // cell_w):
        canvas[:, i * cell_w * zoom] = (0, 255, 0, 255)
    return canvas


# --------------------------------------------------------------------------
# Godot 匯出
# --------------------------------------------------------------------------


def write_sprite_frames(
    path: Path,
    texture_res: str,
    frames: int,
    cell_w: int,
    cell_h: int,
    fps: float,
    idle_frame: int,
    jump_frame: int,
) -> None:
    """寫一份 SpriteFrames .tres,給 AnimatedSprite2D 用。

    跟 strip 一起產而不是在編輯器裡手拉:格數與 cell 尺寸是 --height 的函數,
    改了高度重跑就兩邊同步。手拉的話每次改尺寸都要重來一遍,而且會靜默地
    對不上 —— region 還指著舊的 cell 尺寸,畫面歪掉但不會報錯。

    只有 run 是真動畫。idle 與 jump 各借一格 —— 來源只有跑步循環這 8 格,
    與其讓角色站著不動時繼續跑步,不如凍在一個姿勢上。
    """
    atlas_template = '''[sub_resource type="AtlasTexture" id="AtlasTexture_{i:02d}"]
atlas = ExtResource("1_sheet")
region = Rect2({x}, 0, {w}, {h})
'''
    subs = "\n".join(
        atlas_template.format(i=i, x=i * cell_w, w=cell_w, h=cell_h)
        for i in range(frames)
    )

    frame_template = '''{{
"duration": 1.0,
"texture": SubResource("AtlasTexture_{i:02d}")
}}'''
    anim_template = '''{{
"frames": [{entries}],
"loop": true,
"name": &"{name}",
"speed": {speed}
}}'''

    def anim(name: str, indices: list[int], speed: float) -> str:
        entries = ", ".join(frame_template.format(i=i) for i in indices)
        return anim_template.format(entries=entries, name=name, speed=speed)

    animations = ", ".join(
        [
            anim("idle", [idle_frame], 1.0),
            anim("jump", [jump_frame], 1.0),
            anim("run", list(range(frames)), fps),
        ]
    )

    header = '''[gd_resource type="SpriteFrames" load_steps={steps} format=3]

[ext_resource type="Texture2D" path="{texture}" id="1_sheet"]

'''
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        header.format(steps=frames + 2, texture=texture_res)
        + subs
        + "\n[resource]\nanimations = [" + animations + "]\n",
        encoding="utf-8", newline="\n",
    )

# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="把接觸表切成 Godot 用的精靈圖 strip",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    p.add_argument("source", type=Path, help="來源接觸表 PNG")
    p.add_argument("--out", type=Path, required=True, help="輸出路徑前綴(不含副檔名)")
    p.add_argument("--frames", type=int, default=8, help="格數")
    p.add_argument("--height", type=int, default=22, help="角色目標高度(art px)")
    p.add_argument("--margin", type=int, default=1, help="每格四周留白(art px)")
    p.add_argument("--bg-threshold", default="auto",
                   help="背景亮度門檻(0-255),或 auto 由角色完整性自動推導")
    p.add_argument("--alpha-cutoff", type=float, default=0.4, help="alpha 二值化門檻")
    p.add_argument("--shadow-cut-ratio", type=float, default=0.5, help="陰影偵測的寬度比")
    p.add_argument("--keep-shadow", action="store_true", help="保留地面陰影橫條")
    p.add_argument("--min-blob", type=int, default=2, help="小於這個面積的浮空區塊直接刪掉")
    # 預設 none:這份來源的 8 格 cx 本來就都是 129.5(產生器已置中),
    # center 只會把尾巴與伸長的腿造成的 bbox 偏移變成身體左右抖。
    p.add_argument("--align-x", choices=["center", "none"], default="none")
    p.add_argument("--band", type=int, default=None, help="指定第幾個橫帶(預設最上面)")
    p.add_argument("--no-preview", action="store_true", help="不輸出預覽圖")
    p.add_argument("--godot-frames", type=Path, default=None,
                   help="順便輸出 SpriteFrames .tres 到這個路徑")
    p.add_argument("--texture-res", default=None,
                   help="寫進 .tres 的貼圖 res:// 路徑(預設由 --out 推)")
    p.add_argument("--fps", type=float, default=12.0, help="run 動畫的播放速率")
    p.add_argument("--idle-frame", type=int, default=0, help="idle 借用第幾格(0-based)")
    p.add_argument("--jump-frame", type=int, default=4, help="jump 借用第幾格(0-based)")
    return p


def main() -> int:
    # Windows 主控台預設可能是 cp950,直接 print 中文會炸。
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = build_parser().parse_args()

    sheet = read_png(args.source)
    print(f"來源      {args.source}  {sheet.shape[1]}x{sheet.shape[0]}")

    # 探測 pass:先用極保守的門檻定出橫帶與格邊界。這兩件事對門檻不敏感,
    # 而門檻掃描需要固定的格邊界才能比較。
    probe_fg = ~background_mask(sheet, PROBE_THRESHOLD)[0]
    p_top, p_bottom = pick_band(probe_fg, args.band)
    p_spans, _ = split_columns(probe_fg[p_top : p_bottom + 1], args.frames)

    if str(args.bg_threshold).lower() == "auto":
        threshold, table, ok = choose_bg_threshold(sheet, p_top, p_bottom, p_spans)
        print("門檻掃描  門檻  前景%   最差主區塊佔比  最多區塊數")
        for thr, frac, worst, ncomp in table:
            mark = " <=" if thr == threshold else ""
            print(f"          {thr:4d}  {frac:5.1%}      {worst:6.0%}         "
                  f"{ncomp:4d}   {integrity_verdict(worst)}{mark}")
        if not ok:
            print(f"          !! 沒有任何門檻讓角色保持完整(目標 "
                  f"{INTEGRITY_TARGET:.0%})。來源可能有問題,請人工確認。")
        print(f"          自動選定 --bg-threshold {threshold}")
    else:
        threshold = int(args.bg_threshold)

    bg, trapped = background_mask(sheet, threshold)
    fg = ~bg
    print(f"去背      門檻 {threshold},前景佔 {fg.mean():.1%}")
    if trapped:
        big = [a for a in trapped if a >= 20]
        print(f"          封閉暗區 {len(trapped)} 塊,最大 {trapped[0]}px"
              f"(≥20px 的有 {len(big)} 塊,保留為不透明)")

    top, bottom = pick_band(fg, args.band)
    all_bands = _runs_1d(fg.any(axis=1))
    print(f"橫帶      取 y[{top},{bottom}](共偵測到 {len(all_bands)} 帶"
          f"{',已排除編號列' if len(all_bands) > 1 else ''})")

    band_fg = fg[top : bottom + 1]
    band_px = sheet[top : bottom + 1]
    spans, mode = split_columns(band_fg, args.frames)
    print(f"切格      {mode}")

    # 角色完整性健檢。面積類指標偵測不到「角色被切碎」,這裡才會抓到。
    stats = frame_integrity(band_fg, spans)
    worst = min(f for _, f in stats)
    print(f"完整性    " + "  ".join(
        f"格{i + 1}:{n}塊/{f:.0%}" for i, (n, f) in enumerate(stats)))
    print(f"          最差 {worst:.0%} — {integrity_verdict(worst)}")

    cells = [band_fg[:, x0 : x1 + 1].copy() for x0, x1 in spans]
    widths = np.array([row_widths(c) for c in cells])

    ground = None
    if not args.keep_shadow:
        ground = find_ground_line(widths, args.shadow_cut_ratio)
        if ground is None:
            print("陰影      沒偵測到地面陰影帶,原樣保留")
        else:
            med = np.median(widths, axis=0)
            print(f"陰影      地平線在 local y={ground}(全域判定),以下 "
                  f"{widths.shape[1] - ground} 列丟掉。"
                  f"上一列中位寬 {med[ground - 1]:.0f} → 該列 {med[ground]:.0f}")
            for c in cells:
                c[ground:] = False

    # 共用視窗:所有格用同一個裁切框。
    # **不逐格重新對齊。** 8 格的頭頂本來就齊(top y=10~11)、地平線也是共用的,
    # 動的只有腳。按「各自的 bbox 底」重對齊會把抬腳騰空那幾格硬拉到地面,
    # 跑步循環的抬腳幅度整個消失。
    boxes = []
    for i, cell_fg in enumerate(cells):
        ys, xs = np.nonzero(cell_fg)
        if ys.size == 0:
            raise ValueError(f"第 {i + 1} 格剝完陰影就空了,--shadow-cut-ratio 太高")
        boxes.append((int(ys.min()), int(ys.max()), int(xs.min()), int(xs.max())))
        print(f"  格{i + 1}    bbox {xs.max() - xs.min() + 1}x{ys.max() - ys.min() + 1}"
              f"  頂 y={ys.min()}  底 y={ys.max()}  cx={(xs.min() + xs.max()) / 2:.1f}")

    win_top = min(b[0] for b in boxes)
    win_bottom = max(b[1] for b in boxes)
    win_left = min(b[2] for b in boxes)
    win_right = max(b[3] for b in boxes)
    src_h = win_bottom - win_top + 1
    src_w = win_right - win_left + 1

    # --height 指的是「站在地上的角色」多高,也就是共用視窗的高度:頭頂到地平線。
    scale = args.height / src_h
    out_h = args.height + 2 * args.margin
    out_w = int(np.ceil(src_w * scale)) + 2 * args.margin
    cell_h = int(round(out_h / scale))
    cell_w = int(round(out_w / scale))
    margin_src = (cell_h - src_h) // 2
    print(f"共用視窗  x[{win_left},{win_right}] y[{win_top},{win_bottom}] = {src_w}x{src_h}")
    print(f"降取樣    {src_w}x{src_h} → {out_w - 2 * args.margin}x{args.height}"
          f"(1/{1 / scale:.2f}),cell {cell_w}x{cell_h} → {out_w}x{out_h}")

    strip = np.zeros((out_h, out_w * args.frames, 4), np.uint8)
    total_removed = 0
    for i, cell_fg in enumerate(cells):
        canvas = np.zeros((cell_h, cell_w, 4), np.uint8)
        x_from = win_left
        if args.align_x == "center":
            # 逐格把 bbox 中心推到 cell 中心。跑步循環裡尾巴翹起、前腿伸長都會
            # 拉動 bbox 中心,所以這個模式會讓身體左右抖 —— 只在來源本來就沒
            # 置中的時候才用。
            bx0, bx1 = boxes[i][2], boxes[i][3]
            x_from = int(round((bx0 + bx1) / 2 - src_w / 2))

        dst_y = margin_src
        dst_x = margin_src
        src_y0, src_y1 = win_top, win_bottom + 1
        src_x0 = max(0, x_from)
        src_x1 = min(cell_fg.shape[1], x_from + src_w)
        dst_x += src_x0 - x_from

        patch = band_px[src_y0:src_y1, spans[i][0] + src_x0 : spans[i][0] + src_x1].copy()
        mask = cell_fg[src_y0:src_y1, src_x0:src_x1]
        patch[..., 3] = np.where(mask, 255, 0)
        patch[~mask] = 0
        canvas[dst_y : dst_y + patch.shape[0], dst_x : dst_x + patch.shape[1]] = patch

        small = downscale(canvas, out_h, out_w, args.alpha_cutoff)
        small, removed = despeckle(small, args.min_blob)
        total_removed += len(removed)
        strip[:, i * out_w : (i + 1) * out_w] = small
        fill = (small[..., 3] > 0).sum()
        where = " ".join(f"({x},{y})" for x, y, _ in removed)
        print(f"  格{i + 1}    x 取自 {src_x0}  實心 {fill}px"
              + (f"  去屑 {len(removed)} 塊 @ {where}" if removed else ""))
    if args.min_blob > 1:
        print(f"去屑      共移除 {total_removed} 塊小於 {args.min_blob}px 的浮空區塊"
              "(位置見上,確認那不是尾巴尖或手指)")

    strip_path = args.out.with_suffix(".png")
    write_png(strip_path, strip)
    print(f"輸出      {strip_path}  {strip.shape[1]}x{strip.shape[0]}")

    meta = {
        "source": str(args.source).replace("\\", "/"),
        "frames": args.frames,
        "cell_width": out_w,
        "cell_height": out_h,
        "character_height": args.height,
        "bg_threshold": threshold,
        # 腳底在 cell 裡的位置。Godot 那邊要把 Sprite 往上推這麼多才會踩在地上。
        "baseline_from_bottom": args.margin,
        "generated_by": "tools/make_spritesheet.py",
        "argv": sys.argv[1:],
    }
    meta_path = args.out.with_suffix(".json")
    meta_path.write_text(
        json.dumps(meta, indent=2, ensure_ascii=False) + "\n",
        "utf-8", newline="\n",
    )
    print(f"輸出      {meta_path}")

    if args.godot_frames is not None:
        # res:// 路徑必須相對於專案根目錄。之前這裡是字串裁切,--out 指到專案外
        # 時會產出 res://C:/Users/... 這種永遠載不到的路徑,而且不會報錯。
        if args.texture_res:
            texture_res = args.texture_res
        else:
            try:
                rel = strip_path.resolve().relative_to(Path.cwd().resolve())
            except ValueError:
                raise SystemExit(
                    f"--godot-frames 需要 --out 指向專案目錄內,但 {strip_path} 在外面。"
                    "要嘛把 --out 移進專案,要嘛用 --texture-res 明確指定 res:// 路徑。"
                )
            texture_res = "res://" + rel.as_posix()
        write_sprite_frames(
            args.godot_frames, texture_res, args.frames, out_w, out_h,
            args.fps, args.idle_frame, args.jump_frame,
        )
        print(f"輸出      {args.godot_frames}  → {texture_res}"
              f"(idle=格{args.idle_frame + 1} jump=格{args.jump_frame + 1} run={args.fps}fps)")

    if not args.no_preview:
        preview_path = args.out.with_name(args.out.name + "_preview").with_suffix(".png")
        write_png(preview_path, make_preview(strip, out_w))
        print(f"輸出      {preview_path}(洋紅 = 透明,綠線 = 格線)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
