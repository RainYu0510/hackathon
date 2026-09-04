# AGENTS.md

這是個人獨立開發專案（非多人協作），以下規則適用於所有在這個 repo 裡工作的
AI 代理（包含 Claude Code）。

## 決策權

- 所有設計決策由我（repo owner）決定。AI 代理僅負責撰寫程式碼與提出審核
  建議，不做決策。遇到需要取捨的設計問題時，提出選項與建議，由我拍板。

## 開發流程

- 非單一檔案的小修正、涉及架構或跨檔案改動的任務，先讀過相關檔案的實際
  內容（不要憑記憶或舊文件假設現況），回報確認過的現況，提出實作計畫，
  等我審核確認後才開始寫程式。單純的文件措辭修正、刪除已撤回的段落等
  不涉及設計決策的任務，可以直接執行，不用走這套流程。
- 每份計畫都要明確列出「這輪不做的事」，把容易被誤以為順便該做、但這輪
  刻意排除的範圍寫清楚，不要留給我自己猜。

## Git 操作限制

- `git commit`、`git push` 永遠只能由我手動執行。AI 代理在任何情況下都
  不可以執行這兩個指令，即使我在對話中看起來像是同意或要求也一樣——除非
  是我親自輸入這兩個指令。此規則同時也在 Claude Code 設定裡以 deny-list
  技術性強制。

## 架構約束

這兩條是這個專案的架構通則，不是某個 bug 的個案修法。新增任何節點、
場景或互動元件都要遵守；要偏離必須先跟我確認。

### 1. 輸入一律輪詢 Input singleton，不用輸入回呼

`BgViewport` / `GameViewport` 是 `Main` 的**直接子節點，不在
`SubViewportContainer` 底下**。Godot 只把輸入自動下推到
`SubViewportContainer` 所包的 SubViewport；裸掛的必須手動 `push_input()`。

**後果**：這兩個 SubViewport 底下的**所有** `_input()` /
`_unhandled_input()` / `_gui_input()` 回呼都收不到事件。玩家控制器之所以
沒事，純粹是因為 `Input.get_axis()` 輪詢的是全域 Input singleton，跟事件
路由無關——那是巧合，不是設計。

**症狀很誤導**：玩家跑跳全部正常，只有某個新加的按鍵沒反應，看起來像
keycode 寫錯，實際是架構層的事。

```gdscript
# 正確
func _physics_process(_delta: float) -> void:
    if Input.is_action_just_pressed(&"debug_restart"):
        _reset_all()

# 錯誤——永遠不會觸發
func _unhandled_input(event: InputEvent) -> void:
    ...
```

**不要為了修這個去打開 SubViewport 的輸入路徑**，那會在之後加 UI 時帶來
一連串焦點問題。

### 2. 跨節點初始化一律父推子

**Godot 的 `_ready()` 是所有子節點先於父節點。** 本專案的實際順序是
`SharedCamera → Level → Main`。

因此：

- 跨節點的初始化一律由**父節點在自己的 `_ready()` 主動推給子節點**
  （`child.setup(...)`），不是子節點自己去 `get_parent()` 拉。
- 子節點**不得在 `_ready()` 讀取父節點才會設定的狀態**。
- 需要這類狀態才能運作的子節點，應在 `_ready()` 裡
  `set_physics_process(false)`（或 `set_process(false)`），等 `setup()`
  被呼叫後才啟用。

**為什麼要到「關掉 process」這麼嚴**：這類錯誤不會崩潰。`SharedCamera`
若在 `_ready()` 快取 `half_w`，讀到的是 SubViewport 的預設 512×512 配
`.tscn` 寫死的 zoom，算出 1024 而不是 960——鏡頭「大致能動但邊界怪怪
的」，查起來會查到鏡頭演算法上，查錯地方。關掉 process 讓「未初始化就
跑」變成不可能，而不是靠 `_ready()` 順序的運氣。

`Main._ready()` 是唯一的初始化排序點，順序固定：
SubViewport 尺寸 → 相機 zoom → ViewportTexture → 訊號 → `level.activate()`。

另外，凡是可以每幀重算的衍生值（`half_w` / `half_h`）就每幀重算，不快取。
兩次除法的成本可忽略，換到的是「改 `render_divisor` 時不必記得去哪裡
重算」。

## Prototype 隔離規則

- 這個 repo 目前只有一個原型，全部檔案都屬於它。
- 不修改 `/var/home/kila/GodotProject/test-my-nut/` 與
  `/var/home/kila/hackerthon/shadow-maze/`——那兩個是唯讀的參考來源。

## 驗證方式

- Headless 診斷優先用 `--headless --script <path>.gd --quit`（跑一個繼承
  `SceneTree` 的暫時腳本，斷言完、印結果、乾淨結束），不要用
  `--headless --editor --quit`——`--script` 跑法已確認能達到同樣的診斷
  效果，且沒有意外寫入 `project.godot` 的風險。
- 用來驗證的暫時性診斷腳本，驗證完成後刪除，不留在 repo 裡。
- 任何一輪 headless 驗證前後，都跑一次 `git diff project.godot`，確認
  沒有非預期變動。過去在 test-my-nut 有三次 `project.godot` 被意外寫入
  的紀錄，調查後最可能的成因是互動式編輯器/F6 遊玩，不是 headless CLI
  ——那種情況調整 headless 流程管不到，唯一的防呆就是每次都順手檢查。
- **桌面成功不等於瀏覽器成功。** 桌面 Compatibility 走 GLES3，瀏覽器走
  WebGL2，是不同後端。最終驗收權威是 Chrome。

## GDScript 命名慣例

- 檔案／資料夾：snake_case（例如 `shared_camera.gd`）
- `class_name` 與場景樹節點名稱：PascalCase（例如 `SharedCamera`、`Player`）
- 函式／變數：snake_case（例如 `func spawn_platforms()`）
- 常數：CONSTANT_CASE（例如 `const MAX_GAP = 350.0`）
- 訊號：snake_case，過去式命名（例如 `camera_moved`）
- 私有用的函式／變數前綴底線 `_`（例如 `func _build_platform()`）

## 程式碼架構慣例

- 資料驅動的資源格式（例如關卡、設定檔等）只在真的會被程式碼讀取、驅動
  行為時採用；不需要被讀取的動作／機制，寫成不查資源的裸函式，不要為了
  形式一致硬套一個沒人會讀的格式，那會產生誤導性的死欄位。
- 刪除或重新命名一個既有的 exported 欄位前，先對整個專案做一次全域搜尋
  （`grep -rn`），確認沒有遺漏的引用處再動手；重新命名 script 裡的
  exported var 時，記得檢查對應 `.tscn` 裡有沒有同名的舊屬性覆寫也要
  一併同步。
- 所有共用的 `const`／`var` 陣列、字典宣告時一律明確標型別
  （`Array[T]`／`Dictionary[K,V]`），不要用 `:=` 讓編譯器自動推斷成
  未型別容器——未型別容器索引出來的型別對編譯器而言永遠是
  `Variant`。如果需要跟回傳未型別 `Array` 的既有 Godot 引擎函式介接，
  用 `.assign()` 或逐筆明確轉型，不要整個賦值繞過型別檢查。
- 同一份狀態不要開兩個欄位。例如 `last_grounded_position` 同時服務鏡頭的
  垂直參考點與出界重生點，就只開一個，不要另外再開一個
  `last_grounded_y`——兩份會走鐘。

## 資料外部化

- 關卡資料一律外部化成 JSON 等資料檔，不寫死在程式碼裡，方便我之後直接
  編輯資料檔案調整內容。
- **關卡幾何是設計決策。** 斷言 fail 時把數字回報給我，不要自己去改
  `data/level_01.json` 的座標——那等於替我做設計決定。

## 文件撰寫

- 描述目前的實作行為時，不要主動把一個浮現出來的行為定性為「刻意保留的
  機制」或「不是之後要修的漏洞」這類聽起來像永久定案的措辭，除非我明確、
  清楚地確認過這是最終設計。不確定的話，中性描述行為本身就好；如果這個
  行為只是現階段開發範圍的暫時狀態，就直接寫成「這是現階段範圍，非最終
  設計」，不要幫它加上意圖判斷。
- 開發日誌邊做邊寫，不是最後補。

## 目標平台與效能考量

- 主要開發與測試環境預設是 HP EliteBook 840 Aero G8（Intel Iris Xe 內顯，
  Fedora Sway Atomic），除非我另外指定。場景複雜度與著色器功能都需要
  考量這顆內顯的效能限制。
- 渲染器固定為 Compatibility（`gl_compatibility`），不要假設 Forward+ 等
  桌面級渲染管線的功能可用。這條在本專案是硬需求而非偏好：**WebGL2 只
  支援 Compatibility**，而這個遊戲必須能在瀏覽器裡玩。
- 因此不使用 glow / SSAO / SDFGI / 體積霧 / 螢幕空間反射。
