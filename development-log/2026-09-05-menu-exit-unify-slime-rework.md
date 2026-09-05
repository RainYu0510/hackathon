# 2026-09-05 主選單、過關條件統一、第三關史萊姆重做

對應 issue #2（新增主選單）與 issue #4 的第三關部分。issue #4 的第二關「到最上面
會頂到頭」這輪刻意不處理。

## 1. 除錯數值不再出現在玩家畫面

`LevelBase._build_common()` 建的除錯 HUD（空間／護目鏡持有者／鑰匙／雙方 HP）
原本預設就是顯示的，一開場玩家就看得到。改成 `hud.visible = false`，F1 仍然叫得出來；
`_process()` 裡的文字組裝也加上 `hud.visible` 條件，藏起來時就不走 player group、
不解參照 `health`。

一個容易漏掉的耦合：`F1 HUD  F2 Normal  F3 Alternate  R Reset` 這串**是烤在除錯 HUD
的文字裡**的。HUD 一藏，`R 重來本關` 這個玩家真的會用到的提示就跟著不見。所以把
`R Restart · Esc Menu` 補進永遠顯示的操作提示列；F1/F2/F3 是開發鍵，留在 HUD 裡就好。

## 2. 三關過關條件統一成「兩人都要在門內」

原本三關有三套門邏輯：第一關自己寫 `_door_armed` / `_exit_triggered`、第二關只接
`body_entered` 連武裝都沒有、只有第三關用 `LevelBase.exit_trigger()`。前兩關**一名玩家
進門就過關**，也因此只有第三關會顯示「兩人都要到門口」的提示。

沒有新寫邏輯，把前兩關接到既有的 `exit_trigger()` 上，並改用既有的 `next_scene_path`
欄位串接，不再各自硬寫 `change_scene_to_file`。第一關的 `require_key = true` 保留原本
的鑰匙條件；門的座標與大小都沿用原值，沒有動關卡幾何。

兩個實作上的細節：

- `_update_exit_hint()` 多了「缺鑰匙」分支（`Find the key first`）。缺人跟缺鑰匙是兩種
  不同的卡住，混成同一句話會讓玩家在第一關站在門口猜半天。
- 提示改成**武裝之後才會顯示**。第一關 P1 的出生點 (170,560) 就落在門框
  x[100,200] y[445,615] 內，`body_entered` 在第一幀就會發，提示會在開場瞬間閃出來，
  看起來像壞掉。`_exit_armed`（玩家離開過門框才為 true）本來就是為了擋這件事而存在的，
  提示沿用同一個旗標即可。這一條是 headless 驗證抓出來的，不是猜的。

## 3. 第三關史萊姆（`ChargeMonster`）重做

先釐清一件事：第三關用的**不是** `actors/enemies/Slime/`，是 `ChargeMonster`，
只是借用史萊姆的美術。`Slime.tscn` 至今沒有任何關卡生成，這輪也沒動它。

原本的行為與問題：
- 只要目標在 520px 內就直線走過去，否則**完全站著不動**，沒有巡邏。
- 索敵只看直線距離，不管高低——貓站在高平台上也算「近」。
- 撞完只是 `state = USED` 變成灰色方塊**永遠留在場上**。
- `charge_used` 一旦為 true 就**永不重置**：衝歪一次（撞到普通地形而不是脆弱牆）
  整關就 soft-lock，只能按 R 重來。

改法：

**把「憤怒」從狀態機拆成獨立旗標。** 原本 `_on_dimension_changed()` 會直接覆寫
`state`，所以才需要那個「蓄力中不要被呼叫第二次、免得跑出兩條 coroutine」的特例。
拆成 `enraged: bool` 之後，切維度只改旗標、不干擾移動狀態，特例就不需要了。

**蓄力與暈眩的計時改用 `_physics_process` 的 delta 累加，不用 `await`。** 原本
`_prepare_charge()` 是 `await create_timer(0.8)`，跟狀態切換會賽跑。

**索敵改成高度帶。** 只有 `absf(player.y - monster.y) <= detect_height_band`（預設 80）
的玩家會被偵測到。第三關高平台頂面 y=490、凹槽底頂面 y=600，差 110，80 剛好切開：
貓待在高平台上是安全的，誰下凹槽就追誰，因此 `Level03` 不再需要硬鎖
`target_player_index = 1`。另外加了 0.6 秒的跟丟寬限——玩家跳躍最高約 159px，
會離開高度帶，沒有寬限的話怪物會在每次起跳時抽動一下。

**巡邏。** 沒目標時在 `patrol_min_x`～`patrol_max_x` 之間來回走，碰到牆或走到邊界轉身。
第三關給 1400～2050：左界留在階梯（x[1000,1150]）右邊，右界留在牆（x=2100 起）前面。
這兩個數字是關卡幾何、屬於設計決定，覺得手感不對直接改就好。

**撞破牆 → 死亡消失；撞歪 → 暈眩後可重試。** 前者播 `death`（素材現成 8 張）再
`queue_free()`；後者暈眩 1.5 秒 + 0.6 秒冷卻回到巡邏，貓再切一次空間就能再誘一次。
`charge_used` 整個移除。停滯判定也一併修：原本只用「本幀位移 < 1px」，起衝第一幀
與騰空被卡都會誤觸，改成 `is_on_wall()` 或「已衝刺超過 0.1 秒還幾乎沒位移」。

破牆的耦合點沒動——`BreakableWall.try_break()` 認的還是 group `charging_monster`。

## 4. 主選單

新增 `ui/MainMenu.tscn` + `ui/MainMenu.gd`：開始遊戲／操作說明／離開，操作說明是一塊
可開關的面板，內容跟 README 的操作表一致。Web 版隱藏「離開遊戲」。`project.godot` 的
`run/main_scene` 改指向它——這是本輪 `project.godot` 唯一的變動。

`LevelBase._process()` 加了 `ui_cancel`（Esc）回主選單。`ui_cancel` 是 Godot 內建動作，
不必動 InputMap（已 headless 確認 `InputMap.has_action("ui_cancel") == true`）。
沒有這條的話主選單進得去出不來。

順帶記一下：AGENTS.md 架構約束 1 講的「輸入不會自動下推到裸掛的 SubViewport」在這個
repo **不適用**——全專案 grep 不到任何 `SubViewport`。那條約束是從參考專案帶過來的，
這裡的 Button 與焦點是正常運作的。

## 驗證

`godot --headless --import` 無腳本錯誤（只有一個既有的 UID 重複警告：
`levels/Level03.gd.uid` 與 `levels/Level04.gd.uid` 內容相同，是先前就有的，這輪沒碰）。

寫了兩支繼承 `SceneTree` 的暫時腳本用 `--headless --script` 跑，驗完已刪除：

1. 靜態結構：三關都能 instantiate、`hud.visible == false`、三關都建得出出口提示
   Label 且預設隱藏、前兩關的 `next_scene_path` 都有設、主選單三顆按鈕都在。
2. 史萊姆行為模擬：
   - 情境 A（狗站在怪物與牆之間 → 切異空間）：CHASE → PREPARE → CHARGE →
     牆 `state == BROKEN` → 怪物 DEAD → 播完動畫確實 `queue_free()` 消失。
   - 情境 B（狗在左邊 → 往左衝撞到階梯）：確認真的走過 STUNNED、牆沒破、怪物沒消失、
     離開了 `charging_monster` group，暈眩結束回到巡邏，冷卻過後**還能再蓄力一次**。

模擬時踩到一個值得記的點：衝刺的 `HitBox` 傷害是 99，測試裡沒讓狗閃開就會撞死牠，
而 `GameManager.restart_level()` 會把空間重置回 NORMAL、怪物也就不憤怒了。這是正確
行為（真的在玩時整關會重載），但寫模擬時要記得重新激怒，不然會誤判成「衝歪就再也
不能衝」。

`git diff project.godot` 前後都確認過，只有 `run/main_scene` 那一行。

## 這輪沒做

- 第二關「到最上面會頂到頭（拉高門的平台高度）」——刻意留到下一輪，`data/level_02.json`
  完全沒動。
- issue #3 音效：11 個音檔仍然沒有被播放。
- 暫停選單、音量／按鍵設定、單人模式、存檔。
- 沒幫衝刺怪加 `HurtBox`（玩家攻擊在第三關仍然打不到牠）。
- 沒修 `p2_left` / `p2_right` 的 InputMap keycode。
- 沒把 `Level04` / `*_PLACEHOLDER` 接進流程，也沒刪死碼 `ui/HUD.tscn`。
- 沒動 `actors/enemies/Slime/`。

---

# 追加：選關子頁、暫停面板、彈出視窗背景

## 「1/2/3 關直接進入」是新增功能，不是回歸

被回報「為何 1/2/3 關卡直接進入功能不見了」。查過 `HEAD` 的原始版本後確認
**這個功能從來沒存在過**，把查證結果記在這裡，免得下次又被當成回歸去查：

- 原本 `LevelBase._process()` 只有四個鍵：`F1` 除錯 HUD、`F2` 切**常態空間**、
  `F3` 切**異空間**、`R` 重載本關。
- `project.godot` 只有 `debug_info` / `debug_normal` / `debug_alternate` /
  `reset_room` 四個除錯 action，沒有任何綁到 1/2/3 或選關的東西。
- 這輪從關卡刪掉的只有兩行 `change_scene_to_file`，且都用 `next_scene_path`
  接回**同樣的目的地**。

`F2`/`F3` 是切換空間，很容易被當成「跳第二／三關」——大概就是誤會的來源。

於是在主選單加了「選擇關卡」子頁。三關都能單獨啟動：`LevelBase._ready()` 一進來就
`GameManager.reset_level_state()`，第二、三關的腳本自己會把護目鏡發給 P1，
第一關的護目鏡本來就是地上的 pickup。這件事有寫成 headless 斷言釘住
（直接跳進第二／三關時 P1 `has_goggle == true`），不是靠肉眼看。

## 彈出視窗必須自己蓋 `StyleBoxFlat`

回報「按下按鍵說明，文字跟背後的文字重疊，很難看」。原因是 `PanelContainer` 沒給
`theme_override_styles/panel` 時走 Godot 預設主題，**那是半透明的**，後面的標題與
按鈕會透出來。

修法是每個彈出視窗兩層：全螢幕遮罩 `ColorRect`（`Color(0.02,0.03,0.07,0.82)`）
壓暗背後，加上 `StyleBoxFlat` 的**不透明**底色（`bg_color` 的 alpha 必須是 1）
配邊框與圓角。這條也寫成斷言：三個面板的 `bg_color.a == 1.0`，避免之後有人
順手改樣式又改回半透明。

主選單那邊順便把面板收成一個 `ModalLayer`：遮罩與兩個面板掛在它底下一起開關，
「有沒有彈出視窗開著」只有 `modal_layer.visible` 這一個真相來源，不會出現
「遮罩開著但面板關著」的走鐘狀態。原本 `_on_controls_pressed()` 是直接
`visible = not visible`，面板變成兩個之後那樣寫會兩個同時開著。

## 暫停面板：`process_mode` 是整個機制的關鍵

原本 Esc 是「直接回主選單」——中途沒辦法離開遊戲，而且按下去沒得後悔，進度直接沒了。
改成 Esc 叫出暫停面板（繼續／回主選單／離開遊戲）。

`ui/PauseMenu.tscn` 的根節點 `process_mode` 必須設成 `PROCESS_MODE_WHEN_PAUSED`。
理由不只是「讓它能輪詢 Esc」：

- `get_tree().paused = true` 之後，`LevelBase._process()` 會停掉（它是預設的
  inherit），Esc 就沒人輪詢、面板也收不起來。設成 WHEN_PAUSED 之後，未暫停時由
  `LevelBase` 輪詢 Esc 開啟、暫停時由 `PauseMenu` 自己輪詢 Esc 關閉，兩邊剛好互補，
  不會互搶同一個按鍵。
- **按鈕也一樣**：節點在暫停中沒有 process 的話收不到 GUI 輸入，會變成一個看得到
  但按不動的面板。

另一個容易寫反的地方：「回主選單」必須**先** `paused = false` **再**
`change_scene_to_file()`。順序反過來的話主選單會生在 paused 狀態下，整頁按鈕全部
按不動。這條也寫成斷言（呼叫 handler 之後 `paused == false`）。

## 驗證

一支暫時的 `SceneTree` 腳本（`--headless --script`，跑完已刪除）斷言：

- 主選單四顆按鈕、選關面板三顆關卡按鈕都在；`ModalLayer` 與兩個面板預設全隱藏；
  開一個面板時另一個確實關著；`_close_panel()` 後遮罩關掉。
- `LEVEL_PATHS` 三個路徑 `ResourceLoader.exists()` 都為真。
- 三關各自單獨 instantiate：都有 2 名玩家；第二、三關 P1 有護目鏡、第一關沒有。
- 三關都掛得上暫停面板、預設隱藏、`process_mode == PROCESS_MODE_WHEN_PAUSED`；
  `open()` 後 `paused == true`、`close()` 後 `false`；「回主選單」後 `paused == false`。
- 三個面板的 `StyleBoxFlat.bg_color.a == 1.0`。
- 上一輪的成果沒被弄壞：除錯 HUD 仍預設隱藏、三關的出口提示仍在且預設隱藏。

`git diff project.godot` 這輪是**沒有新增變動**的（只剩上一輪那行還沒 commit 的
`run/main_scene`）。

## 這輪沒做

- 沒加遊玩中的 1/2/3 跳關快捷鍵（選的是主選單子頁）；`F2`/`F3` 維持切空間。
- 沒加關卡進度記錄／解鎖制，三關一律可選。
- 暫停面板不做音量、按鍵設定、存檔。
- 第二關「到最上面會頂到頭」仍未處理，`data/level_02.json` 完全沒碰。
- issue #3 音效仍未接上。

---

# 追加二：Esc 沒反應、焦點白框殘留、選關按鈕副標

## Esc 完全沒反應 —— 同一幀被開了又關

回報「Esc 沒有辦法使用」。用 headless 二分法查出來的，不是猜的：

- **A**：把 `PauseMenu` 自己的 `_process` 關掉，只留 `LevelBase` 的開啟路徑
  → Esc 正常開啟面板（`visible = true`、`paused = true`）。
- **B**：原樣兩邊都在 → 按完 Esc `visible = false`、`paused = false`。

`Input.is_action_just_pressed()` 在**整個 frame** 都回傳 true。idle process 依樹狀
順序跑，父節點先於子節點，而 `PauseMenu` 是關卡的子節點：

1. `LevelBase._process()`（父）看到 just_pressed → `open()` → `paused = true`
2. **同一幀**內 `PauseMenu._process()`（子，剛因為 paused 而開始 process）看到
   **同一個** just_pressed → `close()`

淨效果就是「Esc 完全沒反應」。這個 bug 只在「開關同一個鍵、而兩個 handler 分屬
父子節點」時才會出現，而那正是 WHEN_PAUSED 這套互補設計的副作用。

修法：`open()` 記下 `Engine.get_process_frames()`，`PauseMenu._process()` 在同一幀
直接 return。斷言釘住：三關都要能 Esc 開 → Esc 關 → 再 Esc 開（反覆開關）。

## 焦點白框關掉面板後還留在原地

`Button` 沒給主題時走 Godot 預設的 `focus` 樣式，是一個很突兀的白框；而
`_close_panel()` 原本會把焦點還給「開啟面板的那顆按鈕」，於是面板關掉之後，
主選單上那顆按鈕還掛著一圈白框，看起來像卡住。

兩件事一起修：

- 新增 `ui/menu_theme.tres`，主選單與暫停面板共用。`focus` 樣式改成
  `draw_center = false` + 跟 hover 同色的邊框 —— 鍵盤看得出焦點在哪，但不是白方框。
- `_close_panel()` 改成把焦點整個 `release_focus()` 放掉，並拿掉開場的
  `start_button.grab_focus()`。沒有焦點擁有者時 Godot 的方向鍵導覽會自己抓第一個
  可聚焦控制項，所以鍵盤操作不會斷。面板**開啟**時仍然主動聚焦第一顆按鈕——
  那是 modal，鍵盤要能用。

## 選關按鈕拿掉副標

`第一關  鑰匙折返` / `第二關  雙空間垂直塔` / `第三關  誘導史萊姆破牆`
改成 `第一關  LEVEL 1` / `LEVEL 2` / `LEVEL 3`，跟其他按鈕的中英並排一致。
斷言直接檢查那三個副標字串不再出現在按鈕文字裡。

面板的邊框顏色與大小維持不變（確認過沒問題）。

## 驗證

暫時的 `SceneTree` 腳本（跑完已刪除）斷言：三關 Esc 開／關／再開都正常且
`paused` 同步；主選單開場沒有焦點擁有者、開面板時有、關面板後又沒有；
三顆關卡按鈕不含副標；主題的 `focus` 是 `draw_center == false`。
順便把前幾輪的成果一起釘住：除錯 HUD 仍預設隱藏、出口提示仍在且預設隱藏、
每關 2 名玩家、三個面板底色 `alpha == 1.0`、`LEVEL_PATHS` 三個路徑都存在。

`git diff project.godot` 這輪一樣**沒有新增變動**。
