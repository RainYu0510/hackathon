# 交接文件

**日期**:2026-09-04
**分支**:`feat/pseudo-2d-platformer-prototype`
**狀態**:玩法層、鏡頭、合成層、3D 背景都寫完了,桌面能跑。停在**停點 2**。

---

## 先讀這三份

| 檔案 | 是什麼 |
|---|---|
| [`AGENTS.md`](AGENTS.md) | **規則**。決策權、git 限制、兩條架構約束、命名與程式碼慣例。動手前必讀 |
| [`docs/plan-v5.md`](docs/plan-v5.md) | **計畫**。節點樹、鏡頭演算法、解析度架構、這輪不做的 22 件事、三個停點 |
| [`development-log/2026-09-04-pseudo-2d-platformer-prototype.md`](development-log/2026-09-04-pseudo-2d-platformer-prototype.md) | **現況與理由**。做了什麼、踩到什麼、為什麼這樣決定 |

計畫書的第一段〈計畫演進〉記錄了 v1→v5 被駁回四次的理由。那些結論單獨看
都像沒來由的謹慎,理由留著是為了讓刪之前先知道自己在刪什麼。

---

## 這個原型是什麼

「偽 2D」平台遊戲。玩法邏輯**全部在 2D 平面**(CharacterBody2D + 平台碰撞);
3D 場景只用來當背景,透過 SubViewport render 成貼圖放在 2D 層後面。兩層
完全解耦,各自留一個後製濾鏡插槽(這輪不寫 shader)。

兩個玩家共用**一個鏡頭**,規則是**落後者優先**:鏡頭只由落後的那個人驅動,
永遠不會把他推出畫面;領先者跑再遠鏡頭都不動,直到落後者跟上。

**必須能在瀏覽器裡玩。最終驗收權威是 Chrome,不是桌面執行。**
桌面 Compatibility 走 GLES3、瀏覽器走 WebGL2,是不同後端。

---

## 現在做到哪裡

### 已完成

| 檔案 | 內容 |
|---|---|
| `project.godot` | renderer 鎖 `gl_compatibility`(兩條)、stretch `canvas_items`/`keep`、1920x1080 邏輯尺寸、1280x720 開發視窗、7 個 input action |
| `scenes/main.tscn` | 合成樹:Compositor(兩個 TextureRect)+ BgViewport + GameViewport |
| `scenes/player.tscn` | CharacterBody2D 60x88,layer 2 / mask 1 |
| `scenes/background_3d.tscn` | 三層方塊共 24 個 MeshInstance3D + BoxMesh |
| `scripts/main.gd` | **唯一的初始化排序點**。尺寸→zoom→貼圖→訊號→放行 |
| `scripts/level.gd` | 讀 JSON、生平台、缺口斷言、落差表、R 鍵、出界防護 |
| `scripts/player.gd` | 控制器,`input_prefix` 區分兩人,coyote time |
| `scripts/shared_camera.gd` | 落後者優先的鏡頭演算法 |
| `scripts/background_3d.gd` | 視差驅動 |
| `data/level_01.json` | 12 個平台,4 段地面 + 8 個浮空平台,x 跨 0→6720 |
| `tools/install_export_templates.sh` | 冪等的範本安裝(**bash,Windows 要另外處理**) |

### 驗證過的

- 缺口斷言全過:320 / 300 / 340,上限 350
- **`half_w = 960.0`**(不是 1024)—— 架構約束 2 生效的關鍵證據
- 3D 背景層有透出來,2D 層疊在上面 —— 桌面 OpenGL 下 `transparent_bg` 成立
- 鏡頭 clamp 正確:`trail_x < 960` 時卡在 960,超過才開始跟

### 還沒做

1. **乾淨的行為驗證** —— 上一輪的 log 被真實鍵盤污染(見下方「已知問題」)
2. **owner 親手試玩** —— 停點 2 的重點,手感只能由人判
3. `export_presets.cfg`
4. `tools/serve.py`(本機靜態伺服器,給瀏覽器看用)
5. **匯出到 Chrome** —— 停點 3,**R1 唯一真正的驗證**

---

## Windows 環境重建

### 1. Godot 4.7.2

從 https://godotengine.org/download/windows/ 抓 **Godot 4.7.2 標準版**
(不是 .NET/mono 版,這個專案沒有 C#)。

### 2. 匯出範本

`tools/install_export_templates.sh` 是 bash,Windows 上有三個選擇:

- **最簡單**:開編輯器 → 編輯器 → 管理匯出範本 → 下載並安裝
- 用 Git Bash / WSL 跑那支腳本
- 手動:抓
  `https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz`
  (1.28 GB),解開後把 `templates/` 底下的檔案**攤平**放到
  `%APPDATA%\Godot\export_templates\4.7.2.stable\`

**必須確認裡面有 `web_nothreads_release.zip` 與 `web_nothreads_debug.zip`**
—— 4.3+ 起 no-threads 是獨立的範本檔,名字對不上就是版本假設錯了。

### 3. 建 `.godot/` 快取

`.godot/` 是 gitignore 的,新機器要重建,否則 `class_name Player` /
`SharedCamera` 找不到,會噴五個 Parse Error:

```
godot --headless --path . --import
```

收尾時可能會 abort(`Parameter "singleton" is null`),快取已經正確寫出,
不影響結果。**跑完檢查 `git diff project.godot` 應該是空的。**

### 4. 跑起來

```
godot --path .          # 或直接用編輯器開,按 F5
```

P1 = WASD(W 跳),P2 = 方向鍵(↑ 跳),R = 重置。

---

## Linux 專用、Windows 上不能用的東西

| 東西 | 說明 |
|---|---|
| `tools/install_export_templates.sh` | bash + `unzip`。見上面的替代做法 |
| `flatpak run org.godotengine.Godot` | dev-log 裡的指令都是這個前綴,Windows 直接用 `godot` |
| `grim` | Wayland 截圖工具。Windows 用系統內建的截圖 |
| `~/.var/app/org.godotengine.Godot/data/godot/export_templates/` | Windows 是 `%APPDATA%\Godot\export_templates\` |

`.gitattributes` 已設 `* text=auto eol=lf`,`.gd` / `.tscn` / `.json` 不會
被轉成 CRLF。**這個檔案不在 v5 計畫裡**,是為了跨平台才加的,要拿掉隨時
可以拿掉。

---

## 三個必停回報點

owner 的規則:連續執行,但這三處**停下來回報並等回覆**,不要自己往下走。

### 停點 1 — 落差表 ✅ 已通過

`level.gd` 印出相鄰平台的 Δx / Δy 表,整張貼給 owner 人眼掃。
**缺口斷言 fail 的話一併貼出來,不自己去改 `level_01.json` 的座標** ——
關卡幾何是設計決策。

> 已完成。owner 據此把 `Ledge3` / `Ledge8` 的 y 從 700 抬到 760
> (原本爬升 300,跳躍高度 300.48,餘裕只有 0.48,實務上跳不上去)。

### 停點 2 — 桌面第一次跑起來 ⏸ **現在停在這裡**

要回報:
- `activate()` 印出的 `half_w` 實際值(應為 960;**1024 表示 N1 有一步沒生效**)
- 截圖
- 觀察到的行為:兩人能不能各自動、鏡頭有沒有照落後者優先、3D 背景有沒有視差

**截圖交給 owner 判讀,不下「通過」的結論。**

> 進度:`half_w = 960` ✅、截圖 ✅、**行為證據不乾淨** ❌(見下)

### 停點 3 — 匯出到 Chrome 之後

匯出成功、`serve.py` 起來、頁面能開之後停,附截圖。

**R1 的失敗長得像成功**:`transparent_bg` 在 WebGL2 下失敗時畫面**不是
全黑**,而是 3D 層被 2D 層的黑底蓋掉 —— 看起來像「有畫面、能玩、只是背景
是黑的」。極容易誤判成通過,**這張圖一定由 owner 看**。

### 額外規則 — 偏離計畫就停

實際情況與 v5 不符時停下來回報,不自行判斷改法。包括:tpz 成員名與預期
不同、範本版本對不上、**任何一條斷言 fail**、需要改動 v5 已鎖定的決策
(節點樹、鏡頭演算法、物理常數、renderer)。

小的實作細節(變數命名、函式拆分、log 格式)自己決定,不用問。

---

## 已知問題

### 1. 視窗會搶焦點,行為 log 會被真實鍵盤污染

用 `Input.action_press()` 自動操作 + 視窗執行去驗證行為時,遊戲視窗搶走
焦點,owner 同時在機器上打的字全部進了遊戲 —— P2 在腳本按下它的鍵之前
就開始移動,還有整段以全速往左跑。

**做法**:行為驗證一律走 headless(沒有視窗就不會搶焦點),視窗執行只用來
看畫面。**兩者分開,不要想用同一次執行同時拿到兩種證據。**

### 2. tiling WM 底下視窗不照 1280x720 開

Sway 直接把它平鋪成接近全螢幕。不是專案設定錯誤。Windows 上不會有這個
問題。

### 3. `--import` 收尾會 abort

`Parameter "singleton" is null` at `editor_node.cpp:6618`,然後 core
dumped。快取已經正確寫出,不影響結果。

### 4. R1 還沒真正驗過

桌面 OpenGL 下 `transparent_bg` 是work的,但**WebGL2 才是有風險的那一半**。
若壞掉,退路是「只有 3D 進 SubViewport」的分層 —— 代價是失去 2D 層的獨立
濾鏡插槽。**先回報再改,不要自己決定。**

---

## Git 規則(不可違反)

> `git commit`、`git push` 永遠只能由 owner 手動執行。AI 代理在任何情況下
> 都不可以執行這兩個指令,**即使 owner 在對話中看起來像是同意或要求也一樣**
> ——除非是 owner 親自輸入這兩個指令。

此規則同時在 Claude Code 設定裡以 deny-list 技術性強制。
