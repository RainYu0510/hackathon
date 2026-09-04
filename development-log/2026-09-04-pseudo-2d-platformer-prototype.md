# 日期

2026-09-04

# 主題

pseudo-2d-platformer-prototype

# 計畫演進：v1 → v5 被駁回四次的理由

這一段刻意寫在最前面。下面每一條的**結論**單獨看都像沒來由的謹慎，很容易
在之後重構時被當成多餘的規矩刪掉。理由留在這裡，是為了讓刪之前先知道自己
在刪什麼。

這些問題有一個共同的形狀：**它們不會崩潰**。要嘛是「桌面正常、匯出才炸」，
要嘛是「不崩潰但靜靜地歪掉」。兩種都會把人引到錯的地方去查。

## v1 → v2：瀏覽器是驗收權威

原始計畫預設桌面跑起來就算數。加上硬限制：**這個遊戲必須能在瀏覽器裡玩，
所有驗證的最終權威是 Chrome。** 桌面 Compatibility 走 GLES3、瀏覽器走
WebGL2，是兩個不同後端，桌面成功不構成瀏覽器成功的證據。

連帶：renderer 鎖 `gl_compatibility`、Web 匯出走 no-threads、
`CSGBox3D` 換 `MeshInstance3D + BoxMesh`（CSG 是啟動時 CPU 建構，
網頁啟動已因 WASM 偏長）。

## v2 → v3：四個會直接壞掉的問題

1. **`process_priority` 只影響 `_process`**，`_physics_process` 的排序要用
   `process_physics_priority`。寫錯的話鏡頭會讀到玩家移動**前**的位置——
   正好是這個設計要避免的那件事。
2. **`GameViewport` 少了 `render_target_update_mode = ALWAYS`**。預設是
   `WHEN_VISIBLE`，而裸掛的 SubViewport 可能被判定為不可見 → 第一幀之後
   整個凍結。兩個 SubViewport 都顯式寫死。
3. **`position_smoothing_enabled` 必須在 `.tscn` 裡顯式寫 false**，否則
   之後有人在 Inspector 打開它，會和我們自己的指數平滑疊成雙重平滑。
4. **玩家高度 90 → 88**。88/4 = 22 是整數，90 會得到 22.5。

以及：跳躍能力與關卡缺口本來沒有任何約束關係，補上 `MAX_GAP` 斷言。

## v3 → v4：範圍不對

v3 技術上沒錯，但塞了整套 Playwright 自動化測試與階段 gate。砍掉全部測試
自動化，改成**一次做出可以玩的原型**，然後進入「owner 跑 → 回報 → 我修」
的循環。桌面是開發迴圈，瀏覽器是驗收（只在告一段落時匯出，不是每次改動）。

## v4 → v5：六個問題（N1–N6）

### N1（最嚴重）：`_ready()` 是子先於父

Godot 的 `_ready()` 順序是**所有子節點先於父節點**，實際順序
`SharedCamera → Level → Main`。而 v4 把初始化全放在父節點。

若 `shared_camera.gd` 在 `_ready()` 快取 `half_w`，它讀到的是 SubViewport
的預設 512×512（`main.gd` 還沒改到）配 `.tscn` 寫死的 `zoom = 0.25`：

```
half_w = 512 * 0.5 / 0.25 = 1024   ≠ 960
```

**症狀是「大致能動但邊界怪怪的」**，不是崩潰。查起來會查到鏡頭演算法上。
`bounds` 更糟——第一幀直接拿未初始化的值去 clamp。

三項處置：`half_w`/`half_h` 每幀重算不快取；`bounds` 由上層推下來；
`_ready()` 裡 `set_physics_process(false)`，`setup()` 後才啟用。

第三項讓「未初始化就跑」變成**不可能**，而不是靠順序運氣。

**原始的修法還漏了半個 bug**：owner 提的是「bounds 由 level.gd 推給鏡
頭」，但 `Level._ready()` 也早於 `Main._ready()`——Level 推 bounds 的那
一刻 viewport 尺寸還是 512×512，`setup()` 裡那次 `snap_to_target()` 一樣
會用 1024 算。所以改成 **`Main._ready()` 是唯一的初始化排序點**（它最後
跑，是唯一有資格排序的節點），`Level._ready()` 完全不碰鏡頭，
`Main` 把尺寸/zoom/貼圖/訊號都設好之後才呼叫 `level.activate()`。

### N2：`gl_compatibility` 在 v4 的壓縮中消失了

v3 有這條決策，v4 刪掉那個章節後全文再也沒出現。**不能默認**——Godot 4
預設 Forward+，而 WebGL2 只有 `gl_compatibility`。沒寫死的話桌面用
Forward+ 跑得好好的，直到匯出才炸，而那時 3D 背景的視覺已經照 Forward+
調過一輪，得整個重調。

### N3：`data/level_01.json` 可能不會進 pck

`FileAccess.open("res://data/...")` 在編輯器一定成功（原始檔就在磁碟
上），匯出後不一定——非資源檔要在 export preset 的 `include_filter` 列
出來。症狀又是「桌面正常、匯出後關卡全空」。一行 `include_filter="*.json"`
的保險，不去賭 Godot 4 對 `.json` 的 import 行為。

### N4：出界重生與鏡頭規則直接衝突

出界送回出生點 `x = 200`，但鏡頭是 `trail_x = min(p1.x, p2.x)` 驅動：
P2 在 x=3000 掉坑 → 回 x=200 → `trail_x` 從 3000 瞬間變 200 → 鏡頭一路
滑回開頭 → **還在 3000 的 P1 被丟出畫面**，違反「永不把落後者推出畫面」。

**這不是鏡頭的錯**，鏡頭忠實執行了規格；是重生點的選擇讓規格不可能被
滿足。所以修重生點：出界回**最近的安全落腳點**
（`last_grounded_position`），R 鍵才是回出生點。

### N5：HTML shell 這輪完全不做

v4 的「這輪不做」寫著「只加 `image-rendering: pixelated`」——意思是要
加，但檔案清單沒有 shell、`export_presets.cfg` 也沒指過去。改成完全不
做，**不留半個承諾**。browser 裡糊一點不影響 R1/R2 的判斷；R2 真的中招
時本來就得動這個 shell，到時再一起做。

### N6：寫回被壓縮掉的 stretch 規格

`window/stretch/mode = canvas_items`、`aspect = keep`、開發視窗 1280×720。
**`aspect` 不能用 `expand`**：那會讓可視區隨視窗長寬比浮動，與固定尺寸
的 SubViewport 不符 → 畫面變形，而且 `half_w` 從此不是確定值，整個
「恆為 960」的鏡頭數學不成立。

### 兩項順帶

- `last_grounded_position` 初始值 = 出生點，不是 0。否則第一幀還沒踩到
  地板時垂直參考點是 0，鏡頭被拉到關卡上緣。
- `shared_camera.snap_to_target()` 開成 public，供 `_reset_all()` 呼叫。
- 併成一個 `last_grounded_position: Vector2` 欄位，同時服務鏡頭的 `ref_y`
  與 N4 的重生，不開兩份會走鐘的狀態。

# 環境知識（這輪用不到，但別弄丟）

- **無頭 Chromium 從 M139 起 WebGL context 建立會直接失敗**（不是降級到
  SwiftShader，是失敗）。若之後真要跑無頭瀏覽器測試，必須加
  `--enable-unsafe-swiftshader`，否則畫面全黑，而且**症狀與 R1 架構失敗
  難以區分**——會得到假的失敗結論。
- Chrome 的 Flatpak **沒有 `filesystems=host`**（只有 xdg-download /
  documents / pictures / music / videos、host-etc），所以 Playwright 的
  `executablePath` 指不到它。Godot 的 Flatpak 則有 host，能寫入 repo 內的
  `build/`。
- `flatpak update` 必須帶 `--user`——這台同時有 system 與 user 兩個
  flathub remote，不帶會報 "Remote 'flathub' found in multiple
  installations"。

# 變更內容

（以下邊做邊補）

## 步驟 1–3：分支、專案骨架

- 開分支 `feat/pseudo-2d-platformer-prototype`
- 背景啟動 `flatpak update --user org.godotengine.Godot` 與 4.7.2 匯出範本
  （1.19 GB tpz）下載，與步驟 2–8 並行，不阻塞
- `project.godot`：依〈project.godot 明確規格〉逐條寫，含 7 個 input action
  （physical_keycode 取自 shadow-maze 已驗證的值）
- `.gitignore`：沿用 shadow-maze 那份
- `AGENTS.md`：移植 test-my-nut 慣例，外加兩條架構約束（輸入一律輪詢、
  初始化一律父推子）

## 步驟 4:關卡資料與載入路徑（停點 1）

- `data/level_01.json`：12 個平台（4 段地面 + 8 個浮空平台），x 跨 0→6720。
  座標定義寫在檔案的 `_comment` 裡：**x = 左緣，y = 上緣（踩踏面）**。
  這樣落差表的 Δy 直接就是踩踏面高低差，不用心算 h/2。
- `scripts/level.gd`：載入 → 解析 → 印落差表 → 缺口斷言 → 生平台。
  載入/解析/驗證全部寫成不依賴場景樹的函式，headless 驗證可以直接呼叫。
- 用 `--headless --script` 跑過一次（暫時腳本已刪除，依 AGENTS.md）。

**缺口斷言全部通過**：320 / 300 / 340，上限 350。

**斷言只涵蓋地面列，而落差表掃出兩個垂直問題**：

```
Ground2 -> Ledge3   爬升 300，跳躍高度 300.48，差 0.48
Ground4 -> Ledge8   爬升 300，跳躍高度 300.48，差 0.48
```

落差表的 `備註` 欄沒有標記它們，因為標記條件是「爬升 > 跳躍高度」而
300 < 300.48 —— **剛好落在門檻的正確側，但餘裕只有 0.48 個邏輯單位**。
拋體在頂點速度為零，實務上等於跳不上去。

修訂 14 說「不寫完整可達性演算法，印表給人眼掃」，這正是人眼掃要抓的東西；
但也顯示單純「> 跳躍高度」的標記門檻太鬆，之後若要加標記條件，應該是
「餘裕 < 某個下限」而不是「超過就標」。

兩塊平台都還有另一條下降路線可達（Ledge2→Ledge3 餘裕 218、
Ledge7→Ledge8 餘裕 185），所以不是死路，只是那條直上的路走不通。

**沒有改 `level_01.json` 的座標** —— 關卡幾何是設計決策（AGENTS.md
〈資料外部化〉），數字回報給 owner 決定。

### 一個要誠實記下的驗證缺口

AGENTS.md 要求每輪 headless 前後跑 `git diff project.godot`。這輪跑了，
但 **`project.godot` 目前還是 untracked，所以那個 diff 是空的、不具意義**。
要等 owner 第一次 commit 之後這個檢查才真的有效力。

## 停點 1 的決定與後續（owner 拍板）

owner 選了選項 2：**`Ledge3` / `Ledge8` 的 y 從 700 抬到 760**（爬升 240）。

重算後**沒有任何邊界案例**：

```
Ground2 -> Ledge3   爬升 240（餘裕 60.5）   ← 原本 300 / 餘裕 0.5
Ground4 -> Ledge8   爬升 240（餘裕 60.5）   ← 原本 300 / 餘裕 0.5
Ledge3  -> Ledge4   爬升 240（餘裕 60.5）   ← 連帶影響：原本 180
Ledge2  -> Ledge3   gap 330 / 極限 565（餘裕 235）
Ledge7  -> Ledge8   gap 400 / 極限 599（餘裕 199）
```

`Ledge3 -> Ledge4` 是這個改動的**連帶影響**，不在 owner 問的範圍內但必須
一起驗——只看被改的那兩對會漏掉它。改完所有爬升都是 140 / 200 / 240
三種，最小餘裕 60.5，節奏反而比原本一致。

## 步驟 5-7：玩家、鏡頭、合成層

- `scripts/player.gd` + `scenes/player.tscn`：CharacterBody2D，60x88，
  layer 2 / mask 1（兩個玩家互相穿透）。`teleport_to()` 同時處理位置、
  速度與 `last_grounded_position`。
- `scripts/shared_camera.gd`：`_ready()` 關 process、`setup()` 才放行；
  `_half_extents()` 每幀重算；`_commit()` 統一 clamp → 像素對齊 → 寫入 →
  發訊號，`_physics_process` 與 `snap_to_target()` 共用同一份。
- `scripts/background_3d.gd` + `scenes/background_3d.tscn`：三層方塊，
  共 24 個 MeshInstance3D + BoxMesh。相機在 z=0，層在 z=-60/-30/-15。
- `scripts/main.gd` + `scenes/main.tscn`：唯一的初始化排序點。

### 兩個實作上的坑

**1. `body_color` 這個 export 在 `_ready()` 之後寫沒有用。**
玩家是 `.tscn` 裡的實例，`Player._ready()` 早於 `Level._ready()`。Level
再去寫 `p.body_color` 只會改到變數，ColorRect 不會更新。加了
`set_body_color()` 方法。這是架構約束 2 的同一類問題換個面貌。

**2. 玩家出生點同理。** `Player._ready()` 會把 `last_grounded_position`
設成 `.tscn` 裡的位置。Level 必須用 `teleport_to(spawn)` 而不是直接寫
`position`，否則鏡頭的垂直參考點會留在舊值。

### `class_name` 需要先建 class cache

`--headless --script` 不做全專案掃描，所以 `class_name Player` /
`SharedCamera` 在第一次跑的時候找不到，五個 Parse Error。

跑一次 `--headless --import` 建 `.godot/`（這本來就是 R5「匯出前要先建
快取」要做的事，只是提前了）。**`project.godot` 的 sha256 前後完全相同，
零寫入**——這次是真的有效力的檢查，不是之前那個 untracked 的空檢查。

`--import` 收尾時會 abort（`Parameter "singleton" is null` at
editor_node.cpp:6618，然後 core dumped）。快取已經正確寫出，不影響結果，
但記一下免得下次以為是自己的問題。

## 目前狀態（環境轉移前的中斷點）

**headless 載入測試全綠**：

```
[Main] divisor=4 render=(480, 270) zoom=(0.25, 0.25) 可視世界=(1920.0, 1080.0)
[SharedCamera] setup  viewport=(480.0, 270.0) zoom=(0.25, 0.25)  half_w=960.0 half_h=540.0
[Level] activate:bounds=[P: (0.0, -600.0), S: (6720.0, 1800.0)] initial_cam=(200.0, 900.0)
```

**`half_w = 960.0`，不是 1024** —— N1 的三項處置生效了。

匯出範本已安裝：`4.7.2.stable`，35 個檔案，`web_nothreads_release.zip`
與 `web_nothreads_debug.zip` 都在（R4 成員名檢查通過）。

**還沒做的**：桌面實際跑起來 + grim 截圖（停點 2）、`export_presets.cfg`、
`tools/serve.py`、匯出到 Chrome（停點 3）、README。

## 步驟 8：桌面第一次跑起來（停點 2，證據不完整）

`.godot/` 快取、匯出範本、Godot 4.7.2 都在，遊戲**能開起來、畫面正確**。

### 確認到的

- **`half_w = 960.0`，不是 1024** —— N1 的三項處置生效。這是這輪最重要的
  單一數字，因為 1024 那個失敗模式不會崩潰，只會「邊界怪怪的」。
- **3D 背景層有透出來**。截圖裡看得到三層深藍灰方塊，2D 的平台與玩家疊在
  上面 —— 桌面 OpenGL 下 `transparent_bg` 是work的。**R1 的 WebGL2 側還
  沒驗**，那才是真正有風險的一半。
- 平台、兩個玩家（P1 紅、P2 藍）都正確算繪，pixel 風格的階梯邊緣符合
  divisor=4 的預期。
- 鏡頭 clamp 正確：`trail_x` 低於 960 時鏡頭卡在 960（bounds 左緣 +
  half_w），超過之後才開始跟：

```
trail= 851 -> cam.x= 960
trail=1033 -> cam.x= 988
trail=1243 -> cam.x=1192
trail=1453 -> cam.x=1404
```

### 沒能確認的，以及為什麼

**視窗會搶焦點，行為 log 被真實鍵盤污染。**

用一個暫時場景（`_tmp_autodrive`）以 `Input.action_press()` 自動操作，想
產生「P1 先單獨跑 → 鏡頭不動 → P2 再跑 → 鏡頭才前進」的可判讀畫面。但
Godot 視窗在 Sway 下開起來就搶走焦點，owner 同時在機器上打字，那些按鍵
全部進了遊戲：P2 在腳本按下它的鍵之前 1 秒就開始移動，中間還有整段以全速
**往左**跑 —— 那不是腳本送的輸入。

所以「兩人能不能各自動」「鏡頭有沒有照落後者優先」這兩項**沒有乾淨的
證據**，不能下結論。鏡頭的數字之所以還能用，是因為它只由 `trail_x` 決定，
不管 `trail_x` 是誰造成的。

**下次的做法**：行為驗證一律走 headless（沒有視窗就不會搶焦點），用
`--headless --script` 跑程式化輸入並印數值；視窗執行只用來看畫面。
兩者分開，不要想用同一次執行同時拿到兩種證據。

### 另一個環境問題

**視窗沒有照 `window_width_override` 的 1280x720 開**，Sway 直接把它平鋪
成接近全螢幕。截圖與實際遊玩的比例都不是預期的。這是 tiling WM 的正常
行為，不是專案設定錯誤，但要看到正確比例得讓它浮動（Sway：
`for_window [title="Pseudo 2D Platformer Prototype"] floating enable`）。

### P1 掉進坑裡反覆彈回，是預期行為

自動操作只按右、不按跳，所以 P1 走到 Ground1 右緣（x=1600）就掉進缺口，
被出界防護送回 `last_grounded_position`（缺口邊緣），再往右走、再掉下去。
週期約 0.43 秒，位置在 1620~1802 之間震盪 —— 跟 N4 的設計一致，
不是 bug。

## 遷移到 Windows（2026-09-04）

owner 要換到 Windows 機器繼續。這輪加的檔案：

- `docs/plan-v5.md` —— 計畫書原本在 `~/.claude/plans/` 底下不會跟著 repo
  走，複製進來並加了來歷說明。
- `HANDOVER.md` —— 交接文件：現況、能跑什麼、還沒做什麼、Windows 的環境
  重建步驟、三個停點。
- `README.md` —— 從 `# hackathon` 補成實際的操作說明。
- `.gitattributes` —— **這個不在 v5 計畫裡**，是為了跨 Linux/Windows 才加
  的：`* text=auto eol=lf`，避免 `.gd` / `.tscn` / `.json` 在 Windows 被
  轉成 CRLF 之後整檔顯示成差異。要拿掉隨時可以拿掉。

`git commit` / `git push` 依 AGENTS.md 由 owner 手動執行，這裡不碰。

## 步驟 9:Windows 環境重建(接續步驟 8)

換到 Windows 11 機器上繼續。程式碼零改動,只補機器本地的東西。

### 沿用的與新踩到的

`project.godot` 的 sha256 是 `e2324091...`,**與 Linux 那台完全相同** ——
`.gitattributes` 的 `* text=auto eol=lf` 生效了,`.gd` / `.tscn` / `.json`
沒有被轉成 CRLF。

**新問題:專案路徑有空格**(`C:\Users\Kila\hackerthon\New folder\hackathon`)。
所有 CLI 呼叫、匯出輸出路徑都要引號包好。實務上的規避方式是用
`-WorkingDirectory` + `--path .`,而不是把絕對路徑塞進參數。

**`godot.exe` 是 GUI 版,不寫 stdout。** winget 裝的 `godot.exe` 是
`Godot_v4.7.2-stable_win64.exe`,同目錄還有一支
`Godot_v4.7.2-stable_win64_console.exe`。要抓 `half_w` 那行印出來的值,
必須用 console 版跑,GUI 版重導向 stdout 會拿到空檔。

### `--import` 這次沒有 abort

```
godot --headless --path . --import
```

Windows 官方版跑完 **exit 0,乾淨結束**,沒有 Linux Flatpak 那個
`Parameter "singleton" is null` 的收尾 abort。`Player` / `SharedCamera`
兩個 global class 都正常註冊。

`project.godot` 的 sha256 前後相同、`git diff project.godot` 是空的、
`git status` 乾淨 —— 這是 AGENTS.md 那條檢查**第二次真正有效力**地通過。

### 匯出範本(R4 核對通過)

`tools/install_export_templates.sh` 是 bash + `unzip`,Windows 這輪沒有
腳本化,用一次性指令做完(要不要補一支 `.ps1` 留給 owner 決定):

```bash
curl -L -o "$SCRATCH/godot-4.7.2-templates.tpz" \
  https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz
unzip -l "$SCRATCH/...tpz" | grep -E "version\.txt|web_nothreads"   # 先驗成員名
unzip -o -q -j "$SCRATCH/...tpz" -d "/c/Users/Kila/AppData/Roaming/Godot/export_templates/4.7.2.stable"
```

R4 三條全過:`version.txt` = `4.7.2.stable`(與引擎 `4.7.2.stable.official`
相符)、`web_nothreads_release.zip` 與 `web_nothreads_debug.zip` 都在。
攤平後 35 個檔案落地,與 Linux 那台一致。

### 硬體與 AGENTS.md〈目標平台〉不符

AGENTS.md 寫「主要開發與測試環境預設是 HP EliteBook 840 Aero G8
(Intel Iris Xe 內顯,Fedora Sway Atomic)」。**這台是 NVIDIA GeForce
RTX 4050 Laptop GPU**:

```
OpenGL API 3.3.0 NVIDIA 610.88 - Compatibility - Using Device: NVIDIA - NVIDIA GeForce RTX 4050 Laptop GPU
```

renderer 仍然是 Compatibility(硬需求,沒變),但**效能參考基準變了** ——
在這台跑得順不代表 Iris Xe 跑得順。這是現況記錄,AGENTS.md 要不要改由
owner 決定。

## 步驟 10:停點 2 在 Windows 上重跑

用 console 版開視窗、重導向 stdout、9 秒後全螢幕截圖。

### 確認到的

- **`half_w = 960.0`** —— 與 Linux 那台一致,N1 的三項處置在這台同樣生效。
- 落差表與缺口斷言全過(320 / 300 / 340,上限 350),數字與 Linux 相同。
- **視窗照 1280x720 開**。Sway 平鋪的問題在 Windows 不存在,畫面比例是預期的。
- **3D 背景層有透出來**:截圖裡看得到三層深藍灰方塊,2D 平台與兩個玩家
  (P1 紅、P2 藍)疊在上面。**桌面 OpenGL 下 `transparent_bg` 在 NVIDIA
  上也成立**(Linux 那台是不同 GPU,這是第二個桌面資料點)。
- stderr 全空,沒有任何錯誤或警告。

### 又一次沒拿到乾淨的行為證據 —— 但成因與 Linux 那次相反

截圖時(啟動 +9 秒)**兩個玩家都不在出生點**:出生點是 (200, 900) / (340, 900),
截圖裡 P1 在 world x≈1490、站在 Ledge2(y=560),P2 在 world x≈916 半空中。
兩人都往右移動且都離開了地面 —— 上升需要跳躍,而且兩人位置不同,代表
**WASD 與方向鍵兩組輸入都被用到了**。

沒有輸入不可能發生;程式也沒有任何自動驅動(這輪沒寫自動操作腳本)。
所以那 9 秒裡有人在玩。**但我無法歸因**,所以不把它當成行為證據。

Linux 那次的成因是「腳本自動操作 + 視窗搶焦點 → 真人按鍵污染腳本的 log」;
這次沒有腳本,只有真人。**同樣的結論:視窗執行只用來看畫面,不用來蒐證。**

之後行程結束(`stderr` 全空、無 crash trace),應該是被手動關掉的。

## 步驟 11:`export_presets.cfg` 與 `tools/serve.py`

### `export_presets.cfg`

手寫,Web preset 一個。關鍵幾行:

```ini
export_filter="all_resources"
include_filter="*.json"          # ◀ N3
custom_features=""               # 不加任何 custom feature tag
export_path="build/web/index.html"
script_export_mode=2

variant/thread_support=false     # no-threads
html/custom_html_shell=""        # ◀ N5,不指任何 shell
html/export_icon=false           # 這專案沒有 icon 檔
html/focus_canvas_on_start=true
html/canvas_resize_policy=2
```

`export_filter` / `script_export_mode` / `canvas_resize_policy` 這幾個**必須顯式
寫**:手寫的 cfg 缺鍵時 Godot 讀到 nil,`export_filter` 空字串會變成什麼都不
打包,`canvas_resize_policy` 缺了會退成 0。不是「照抄預設值」,是「缺了會壞」。

`vram_texture_compression/*` 兩個都關 —— 這專案沒有任何匯入的貼圖(純
ColorRect + BoxMesh),開著只會多一輪沒有對象的壓縮流程。

### `tools/serve.py`

標準庫 `http.server`,沒有任何第三方相依。四件事:

- port 8099,綁 `127.0.0.1`
- `.wasm` → `application/wasm`、`.pck` → `application/octet-stream`
- 一律送 `Cache-Control: no-store, max-age=0`
- **不送 COOP/COEP**

用 `functools.partial(Handler, directory=...)` 指根目錄,**不用 `os.chdir`**
—— 專案路徑有空格,而且 chdir 會污染同一個行程後續的相對路徑。

**Windows 的坑:`python` 指到 Microsoft Store 的 stub**
(`%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe`),跑下去會開市集然後
exit 49。要用 `py tools/serve.py`,或直接指
`%LOCALAPPDATA%\Programs\Python\Python313\python.exe`。

## 步驟 12:匯出與停點 3

```
godot --headless --path . --export-release "Web" "build/web/index.html"
```

exit 0。打包過程裡最重要的一行:

```
[   1% ] savepack | Storing File: res://data/level_01.json
```

**N3 生效了** —— 關卡 JSON 真的進了 pck。產出 `index.wasm` 39.5 MB、
`index.pck` 34 KB、`index.js` 280 KB。

### Chrome 的實際結果

`serve.py` 起來後 `curl` 先驗過標頭:`.wasm` 回 `application/wasm`、
`.pck` 回 `application/octet-stream`、`Cache-Control: no-store`、沒有
COOP/COEP。然後用乾淨的暫時 profile 開 Chrome。

**console 開頭三行(這是這一整輪最重要的證據)**:

```
Godot Engine v4.7.2.stable.official.ed1daf0bf
OpenGL API OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) - Compatibility - Using Device: WebKit - WebKit WebGL
Build configuration: Emscripten 4.0.20, single-threaded, no GDExtension support.
```

- **WebGL 2.0**,Compatibility —— renderer 鎖 `gl_compatibility`(N2)是對的
- **single-threaded** —— no-threads 範本確實被用上

接著 console 印出完整落差表與缺口斷言(全過),以及:

```
[Main] divisor=4 render=(480, 270) zoom=(0.25, 0.25) 可視世界=(1920.0, 1080.0)
[SharedCamera] setup  viewport=(480.0, 270.0) zoom=(0.25, 0.25)  half_w=960.0 half_h=540.0
[Level] activate:bounds=[P: (0.0, -600.0), S: (6720.0, 1800.0)] initial_cam=(200.0, 900.0)
```

**`half_w = 960.0` 在瀏覽器裡也一樣。** Godot 側零 error / 零 warning。
`chrome_debug.log` 裡其餘的 ERROR 行全是 Chrome 自己的(Adobe PDF 擴充、
USB 列舉、GCM 註冊),與這個專案無關。

### 截圖裡看到的(R1,不由我下結論)

畫面**不是黑底**:三層深藍灰的 3D 方塊透出來,2D 平台與兩個玩家(P1 紅、
P2 藍)疊在上面,兩人都在出生點的地面上。與桌面截圖的構圖一致。

R1 的失敗模式正好是「有畫面、能玩、只是背景是黑的」,而這裡背景有內容,
所以**看起來**對稱雙 SubViewport 架構在 WebGL2 下成立。判讀權在 owner。

### R2 尚未驗證

方向鍵會不會捲動頁面,要真的按下去才知道 —— 畫面沒有捲軸不代表沒中招。
**這輪不預先處理**(N5),等 owner 玩過再說。

## 步驟 13:停點 3 的判讀結果(owner)

- **R1 沒問題** —— WebGL2 下 3D 背景有透出來,對稱雙 SubViewport 架構成立。
- **R2 正常** —— 方向鍵在瀏覽器裡的行為與桌面一致,沒有捲頁問題。
  **不需要自訂 HTML shell**,N5 的「完全不做」維持不變。

兩個風險都拆掉之後,這輪的架構驗證告一段落。

## 步驟 14:鍵盤 rollover 實測與 P2 改鍵

owner 回報「兩角色不能同時跳躍和前進」。plan-v5 的 R3 預期過這件事,但
**不能靠預期定案** —— 要先分清楚是硬體丟鍵還是程式 bug。

### 診斷方法

做了一個只有 `keydown` / `keyup` 的網頁(放 scratchpad,repo 不動):顯示
當下按住的鍵、逐題要求按住指定組合、全部到齊自動判 PASS、按不出來由人點
FAIL。**刻意不經過 Godot** —— 如果連純瀏覽器都收不到那顆鍵,就證明它在
鍵盤內部就被丟掉了,與遊戲程式無關。

每個 P2 候選測四種方向組合(`A`/`D` × P2 左/右)。只測一邊會漏掉一半,
因為 `A` 和 `D` 在矩陣上是不同位置。

### 結果

```
## 基準
  PASS   P1 一個人跑 + 跳            [D + W]
  PASS   兩人只移動,都不跳          [D + →]
  PASS   兩人只跳,都不移動          [W + ↑]
## 方向鍵(原本的設定)
  PASS   P1 左+跳,P2 左+跳          [A + W + ← + ↑]
  FAIL   P1 左+跳,P2 右+跳          [A + W + → + ↑]
  PASS   P1 右+跳,P2 左+跳          [D + W + ← + ↑]
  FAIL   P1 右+跳,P2 右+跳          [D + W + → + ↑]
## IJKL
  PASS × 4
## 數字鍵盤 4 / 6 / 8
  PASS × 4
```

(右 Shift / 數字鍵盤 0 那三組 owner 說是故意失敗的,資料不採計。)

### 讀出來的兩件事

**1. 不是數量上限,是幾何衝突。** `←` 全過、`→` 全掛;而 IJKL 與數字鍵盤
**同樣是四鍵、同樣全過**。所以這張鍵盤四鍵沒問題,純粹是 `W` / `↑` / `→`
三顆在矩陣裡構成長方形,韌體為了不回報鬼鍵把 `→` 丟掉。

**2. 程式沒有問題。** 診斷頁沒有跑任何一行 `player.gd`,連 Godot 都沒進去,
同一組四鍵換成 IJKL 就過 —— 程式碼不會挑物理鍵位。`scripts/player.gd`
未改動。

失敗模式對上症狀:**這關是往右走的**,P2 的主要移動方向就是 `→`,所以
「P2 往右跑同時跳」在 P1 也跳的時候會消失。

### 改法

`project.godot` 的 `p2_*` 改綁 **IJKL**(`I` 在 `J`/`L` 上方,是 WASD 的
右手鏡像,手型完全一樣),外加**數字鍵盤 4/6/8** 當第二組 —— Godot 的
InputMap 一個 action 可以綁多個事件,兩組並存零代價。

**方向鍵拿掉**,不留著。留著等於留一條會靜默壞掉的路,下次有人用方向鍵玩
會撞上同一件事,而症狀一樣不明顯。

鍵碼用 headless 印出來確認過,不用猜:`I`=73 / `J`=74 / `L`=76、
`KP_4`=4194442 / `KP_6`=4194444 / `KP_8`=4194446。改完再 headless 讀回
`InputMap.action_get_events()` 驗證解析正確。

**還沒驗的:NumLock 關閉時數字鍵盤那組是否仍有效。** Windows 在 NumLock
關閉時對數字鍵送的是方向鍵的掃描碼,診斷頁用的是 `event.code`(永遠回
`Numpad4`),Godot 用的是 physical keycode,兩者不保證一致。主力是 IJKL,
它沒有這個依賴,所以不阻擋;數字鍵盤那組當加分項,待實測。

### 一件要記在設計階段的事

現在每人最多同時兩顆鍵(方向 + 跳),兩人合計 4 顆,剛好是這張鍵盤撐得住
的量。**玩法若要加第三個動作**(抓取、衝刺、互動),就變成每人 3 顆、合計
6 顆,**必須重測**,現在這張表不能外推。

## 步驟 15:出界重生改成「兩人一起回出生點」

owner 拍板推翻 N4 的「回最近的安全落腳點」。

**這不是把 N4 的理由否決掉,是它的前提消失了。** N4 當初的問題是:只把
一個人送回起點 → `trail_x = min(p1.x, p2.x)` 暴跌 → 鏡頭滑回開頭 → 還在
遠處的另一個玩家被推出畫面。**兩人一起回**的話沒有人留在遠處,衝突不存在,
鏡頭 `snap_to_target()` 一次就位,「永不把落後者推出畫面」仍然成立。

實作是把 `_guard_out_of_bounds()` 從「個別 `teleport_to(last_grounded_
position)`」改成「任何一人出界就呼叫 `_reset_all()` 並 return」,`_reset_all()`
加一個 `reason` 參數區分是 R 鍵還是出界,log 才分得出來。

**連帶效果(是決定,不是副作用)**:

1. 一個人失誤兩個人一起被拉回去 —— owner 要的合作壓力。
2. 出界與 R 鍵變成同一個行為。
3. **`last_grounded_position` 不再兼任重生點**,只服務鏡頭的垂直參考點。
   欄位保留(鏡頭仍需要),但 `player.gd` 的註解與 AGENTS.md 裡拿它當
   「一個欄位服務兩件事」範例的那段都跟著改了 —— 規則本身不變,只是例子
   的事實基礎變了。

# 已知問題

（待補）

# 下一步

（待補）

# 是否已 commit（若適用）

尚未提交（依 AGENTS.md，`git commit` / `git push` 一律由 owner 手動執行）
