> **這份檔案的來歷**:原本是 Claude Code plan mode 產生的計畫檔
> (`~/.claude/plans/2d-tranquil-thimble.md`),放在家目錄底下不會跟著 repo 走。
> 2026-09-04 為了遷移到 Windows 機器,原封不動複製進 repo。
>
> 內容是**計畫,不是現況**。實際做到哪裡看
> [`../development-log/2026-09-04-pseudo-2d-platformer-prototype.md`](../development-log/2026-09-04-pseudo-2d-platformer-prototype.md),
> 交接請看 [`../HANDOVER.md`](../HANDOVER.md)。
>
> 計畫定案後 owner 又追加了三個必停回報點,見本文〈停點〉一節。

---

# 偽 2D 平台遊戲原型 — 實作計畫 v5(直接做到能玩)

## Context

repo `hackerthon/hackathon` 目前只有 `LICENSE` 與 `README.md`(內容只有 `# hackathon`),**沒有 Godot 專案**。全部從零建立。

目標:**一次做出可以玩的原型**,然後進入「你跑 → 你回報 → 我修」的循環。玩法邏輯全在 2D 平面,3D 場景透過 SubViewport render 成貼圖當背景,兩層解耦、各留一個後製濾鏡插槽。

**計畫通過後連續執行到底,但有三個必停的回報點**(見〈停點〉)。除了那三處與「偏離計畫」的情況,不停下來等審核。

### 迭代方式

**桌面是開發迴圈,瀏覽器是驗收。** 你平常用 `godot` 直接開來回報問題;匯出範本仍要裝,但只在告一段落時匯出讓你在 Chrome 確認。**不會每次改動都重新匯出。**

---

## 與 v3 的差異

**砍掉**(不寫、不建檔):`tools/web_test.mjs` 與 9 條 Playwright 斷言、`tools/run_web_tests.sh`、`scripts/debug_bridge.gd` 與 `window.__godot_state` 協定、`package.json` / `npx playwright install`、`verify_prototype.gd`、`export_presets.cfg` 的 `debug_bridge` feature tag、`serve.py` 的 COOP/COEP 標頭、0-4 / 0-5 兩個煙霧測試場景。

**保留**:AGENTS.md 移植、dev-log、`render_divisor` 旋鈕、兩個 `TextureRect` 濾鏡插槽、v3 的節點樹 / 鏡頭演算法 / Input Map / 物理常數 / `level_01.json`、`tools/serve.py`(改為瀏覽器檢視用途)。

**新增 5 + 2 項修訂**,見下。

## v5 追加(你的 N1–N6 + 2 項順帶)

| # | 修的東西 | 寫在哪一節 |
|---|---|---|
| N1 | `_ready()` 子先於父 → 鏡頭拿到未初始化的 `half_w` / `bounds` | 〈架構約束 2:初始化一律父推子〉 |
| N2 | `gl_compatibility` 從 v4 消失 | 〈project.godot 明確規格〉 |
| N3 | `level_01.json` 可能沒進 pck | 〈project.godot 明確規格〉末 |
| N4 | 出界重生把鏡頭拖回起點、順手把另一人推出畫面 | 修訂 5 |
| N5 | HTML shell 這輪完全不做 | 不做 #19、R2 |
| N6 | 寫回 v3 的 stretch 規格 | 〈project.godot 明確規格〉 |
| 順帶 1 | `last_grounded_y` 初始值 = 出生點 y | 鏡頭演算法 |
| 順帶 2 | `shared_camera.snap_to_target()` 公開 | 鏡頭演算法、修訂 5 |

---

## 環境查證結果

| 項目 | 現況 |
|---|---|
| Godot | Flatpak 4.7.1 stable(user 安裝)→ 升 4.7.2 |
| Godot 沙盒 | `filesystems=host` → 能寫入 repo 內 `build/` |
| **匯出範本** | **目錄是空的**,必須手動安裝 |
| 4.7.2 範本 tpz | HTTP 200,**1.19 GB**(已驗證 URL) |
| Chrome | Flatpak `com.google.Chrome` 152.0.7977.75 |
| git | `main`,乾淨,origin = `github.com/RainYu0510/hackathon.git` |

參考來源(**不同 repo,不會被改動**):`test-my-nut/AGENTS.md`、`shadow-maze/project.godot`(Input Map 文字格式與 keycode 實值)。

---

## Branch

```bash
git switch -c feat/pseudo-2d-platformer-prototype
```

`git commit` / `git push` **一律由你手動執行**(AGENTS.md,且 settings.json 有 deny-list 強制)。

---

## 架構約束 1:輸入一律輪詢(修訂 11,推廣自你的第 1 點)

兩個 SubViewport 是 `Main` 的**直接子節點,不在 `SubViewportContainer` 底下**。Godot 只會把輸入自動下推到 SubViewportContainer 所包的 SubViewport,裸掛的必須手動 `push_input()`。

**後果比單一 bug 更廣**:SubViewport 底下的**所有** `_input()` / `_unhandled_input()` / `_gui_input()` 回呼都收不到事件,不只 `debug_restart`。玩家控制器之所以沒事,純粹是因為 `Input.get_axis()` 輪詢的是全域 Input singleton,跟事件路由無關。

**症狀會很誤導**:兩個玩家都能正常跑跳,只有 R 鍵沒反應 — 看起來像 keycode 寫錯,實際是架構層的事。

**通則**:這個架構下**一律用 Input singleton 輪詢,不用任何輸入回呼**。

```gdscript
# level.gd — 正確
func _physics_process(_d: float) -> void:
    if Input.is_action_just_pressed(&"debug_restart"):
        _reset_all()

# 錯誤 — 永遠不會觸發
func _unhandled_input(event: InputEvent) -> void: ...
```

**不去開 SubViewport 的輸入路徑**,那會在之後加 UI 時帶來一連串焦點問題。這條寫進 `AGENTS.md`,之後加任何互動元件都要遵守。

---

## 架構約束 2:初始化一律父推子(N1)

**Godot 的 `_ready()` 是所有子節點先於父節點。** 實際順序:`SharedCamera → Level → Main`。v4 把初始化全放在父節點,而需要這些值的是最先跑的子節點 — 順序剛好相反。

**症狀不會是崩潰,這才是問題所在。** 若 `shared_camera.gd` 在 `_ready()` 快取 `half_w`,它讀到的是 SubViewport 的**預設 512×512**(`main.gd` 還沒改)配 `.tscn` 寫死的 `zoom = 0.25`:

```
half_w = 512 * 0.5 / 0.25 = 1024   ≠ 960
```

鏡頭「大致能動但邊界怪怪的」,而我會去查鏡頭演算法 — 查錯地方。`bounds` 更糟:第一幀直接拿未初始化的值去 clamp。

### 三項處置(缺一不可)

**1. `half_w` / `half_h` 每物理幀重算,不快取**

```gdscript
func _physics_process(delta: float) -> void:
    var vp_size := get_viewport_rect().size      # 或 get_viewport().size
    var half_w := vp_size.x * 0.5 / zoom.x
    var half_h := vp_size.y * 0.5 / zoom.y
```

兩次除法,成本可忽略。附帶好處:之後改 `render_divisor` 自動跟上,不必記得去哪裡重算。

**2. `bounds` 由上層推下來,不是鏡頭自己去拉**

```gdscript
# shared_camera.gd
func setup(p_bounds: Rect2, p_initial_pos: Vector2,
           p1: Node2D, p2: Node2D) -> void:
    _bounds = p_bounds
    _p1 = p1
    _p2 = p2
    position = p_initial_pos
    snap_to_target()
    set_physics_process(true)        # ← 到這裡才開始跑
```

**3. `_ready()` 裡 `set_physics_process(false)`**

```gdscript
func _ready() -> void:
    set_physics_process(false)       # setup() 之前不准跑
```

讓「未初始化就跑」變成**不可能**,而不是靠順序運氣。這是三項裡最重要的一項 — 前兩項讓它現在是對的,第三項讓它之後改壞時會立刻炸而不是靜靜地歪掉。

### 初始化排序點:`Main._ready()`

`Main` 是最頂層、最後 `_ready()`,所以它是唯一有資格排序的地方。**固定順序**:

```gdscript
# main.gd — _ready() 的完整順序,不可調換
func _ready() -> void:
    var render_size := LOGICAL_SIZE / render_divisor
    bg_viewport.size   = render_size          # 1. 先把尺寸設對
    game_viewport.size = render_size
    camera.zoom = Vector2.ONE / render_divisor  # 2. 再把 zoom 設對
    background_view.texture = bg_viewport.get_texture()    # 3. 接貼圖
    gameplay_view.texture   = game_viewport.get_texture()
    camera.camera_moved.connect(background_3d.on_camera_moved)  # 4. 接訊號
    level.activate()                          # 5. 最後才放行
```

`level.activate()` 內部呼叫 `camera.setup(_bounds, _initial_camera_pos, _p1, _p2)`。`Level._ready()` 只做「讀 JSON、生平台、生玩家、算 bounds」,**完全不碰鏡頭**。

到 `activate()` 被呼叫時,viewport 尺寸與 zoom 都已經是對的,`snap_to_target()` 算出來的 `half_w` 就是 960。

**寫進 `AGENTS.md`(與架構約束 1 並列)**:

> 本專案跨節點初始化一律由父節點在自己的 `_ready()` 主動推給子節點;子節點不得在 `_ready()` 讀取父節點才會設定的狀態,並應在 `_ready()` 關掉自己的 process,等 `setup()` 被呼叫後才啟用。

---

## 解析度架構

```gdscript
const LOGICAL_SIZE := Vector2i(1920, 1080)   # 世界座標空間,永不改變
@export var render_divisor: int = 4          # 1→1920×1080  2→960×540
                                             # 3→640×360    4→480×270  6→320×180
render_size       = LOGICAL_SIZE / render_divisor
GameViewport.size = render_size
BgViewport.size   = render_size              # 兩層共用同一像素網格
SharedCamera.zoom = Vector2.ONE / render_divisor
```

| 項目 | 隨 `render_divisor` 改變? |
|---|---|
| 關卡座標 / 物理常數 | ❌ 永遠是 1920×1080 尺度 |
| `half_w` = `(1920/d)*0.5/(1/d)` | ❌ **恆為 960** |
| 兩個 SubViewport 的實際像素數 | ✅ 唯一會變的 |

**關卡永遠不用重畫。** 拉高畫質 = 把 `4` 改成 `1`。

專案設定 `snap_2d_transforms_to_pixel` / `snap_2d_vertices_to_pixel` 都開,兩個 TextureRect 一律 `texture_filter = NEAREST`。

---

## 完整節點樹

```
Main (Node2D)                            [scripts/main.gd]
│   職責:接線 + 唯一的初始化排序點(架構約束 2)
│         尺寸 → zoom → ViewportTexture → camera_moved 訊號
│         → level.activate() 放行鏡頭
│
├── Compositor (CanvasLayer)             layer = 0
│   ├── BackgroundView (TextureRect)     full rect, NEAREST
│   │       ★【3D 後製濾鏡的 material 插槽】(這輪不寫 shader)
│   │       texture      = BgViewport.get_texture()
│   │       expand_mode  = EXPAND_IGNORE_SIZE          ◀ 修訂 16
│   │       stretch_mode = STRETCH_SCALE
│   └── GameplayView (TextureRect)       full rect, 疊上層, NEAREST
│           ★【2D 後製濾鏡的 material 插槽】(這輪不寫 shader)
│           texture      = GameViewport.get_texture()
│           expand_mode  = EXPAND_IGNORE_SIZE          ◀ 修訂 16
│
├── BgViewport (SubViewport)             ── 3D 背景層
│   │   size = LOGICAL_SIZE / render_divisor
│   │   own_world_3d = true
│   │   render_target_update_mode = ALWAYS
│   └── Background3D (Node3D)            [scripts/background_3d.gd]
│       ├── Camera3D                     perspective, fov 可調
│       ├── DirectionalLight3D
│       ├── WorldEnvironment             純色背景(不用 glow/SSAO)
│       ├── LayerFar  (Node3D)  z ≈ -60  MeshInstance3D + BoxMesh
│       ├── LayerMid  (Node3D)  z ≈ -30
│       └── LayerNear (Node3D)  z ≈ -15
│
└── GameViewport (SubViewport)           ── 2D 玩法層
    │   size = LOGICAL_SIZE / render_divisor
    │   transparent_bg = true
    │   render_target_update_mode = ALWAYS
    │
    └── Level (Node2D)                   [scripts/level.gd]
        │   職責:_ready() 只做「讀 JSON → 生平台/玩家 → 算 bounds」,
        │         不碰鏡頭;activate() 才把 bounds 與玩家推給鏡頭。
        │         之後每幀:輪詢 debug_restart、出界防護。
        │         載入時印相鄰平台落差表。
        ├── Platforms (Node2D)
        │   └── Platform_* (StaticBody2D)      collision_layer=1, mask=0
        │       ├── CollisionShape2D (RectangleShape2D)
        │       └── ColorRect                  position = -size/2
        ├── Player1 (CharacterBody2D)    input_prefix="p1"
        │   │                            collision_layer=2, mask=1
        │   ├── CollisionShape2D (RectangleShape2D 60×88)
        │   └── ColorRect
        ├── Player2 (CharacterBody2D)    input_prefix="p2"
        └── SharedCamera (Camera2D)      [scripts/shared_camera.gd]
                zoom                       = Vector2.ONE / render_divisor
                process_callback           = CAMERA2D_PROCESS_PHYSICS  ◀ 修訂 12
                process_physics_priority   = 10
                position_smoothing_enabled = false
                limit_left/top/right/bottom = 顯式寫成引擎預設值      ◀ 修訂 12
                signal camera_moved(pos: Vector2)
                _ready(): set_physics_process(false)                  ◀ N1
                setup(bounds, initial_pos, p1, p2)  ← 由 Level 推入
                snap_to_target()  public,供 _reset_all() 呼叫       ◀ 順帶 2
```

**碰撞層**:平台 layer 1;兩個玩家都在 layer 2 但 mask 只有 1 → 互相穿透。

**ColorRect 對齊**:`ColorRect` 從左上角定位,`CollisionShape2D` 從中心,生成時設 `color_rect.position = -size / 2`。

### 修訂 12:Camera2D 的兩個 Inspector 陷阱

- **`process_callback` 預設是 `IDLE`**。演算法整個跑在 `_physics_process`,必須在 `.tscn` 寫死 `CAMERA2D_PROCESS_PHYSICS`。修訂 1 修的是**節點**的 `process_physics_priority`,那是不同的東西,兩個都要。
- **`limit_left/right/top/bottom` 顯式寫成引擎預設值**。我們自己做 clamp,日後有人在 Inspector 設了內建 limit 就變雙重 clamp — 跟 `position_smoothing_enabled` 擔心的雙重平滑是同一類失敗。

### 修訂 16:TextureRect 的 `expand_mode`

顯式寫 `EXPAND_IGNORE_SIZE`。480×270 的 ViewportTexture 要填滿 1920×1080 的 rect,預設 `EXPAND_KEEP_SIZE` 會把 minimum size 設成 480×270 影響 layout。既然是手寫 `.tscn`,沒理由不寫死。

---

## 鏡頭演算法

`SharedCamera (Camera2D)`,跑在 `_physics_process`。**前進方向**:`forward = +x`,**落後者 = x 較小者**,開 `@export var forward_sign := 1.0` 供翻轉。

```
# ── 每幀重算,不快取(N1)──
half_w = viewport.size.x * 0.5 / zoom.x   # 恆為 960
half_h = viewport.size.y * 0.5 / zoom.y   # 恆為 540

# ── 水平:只由落後者驅動 ──
trail_x  = min(p1.x, p2.x)        # forward_sign < 0 時改 max()
target_x = trail_x

# ── 垂直:用「最後落地的 y」避免跳躍時鏡頭抖 ──
# last_grounded_position 初始值 = 出生點(順帶 1),不是 0 ——
# 否則第一幀還沒踩到地板時 ref_y 會是 0,鏡頭被拉到關卡上緣。
ref_y(p) = p.is_on_floor() ? p.y : p.last_grounded_position.y
target_y = (ref_y(p1) + ref_y(p2)) * 0.5

# ── 死區 ──
if abs(target_x - cam.x) < deadzone_x : target_x = cam.x
if abs(target_y - cam.y) < deadzone_y : target_y = cam.y

# ── 平滑(frame-rate 無關;內建平滑已顯式關閉)──
t   = 1.0 - exp(-smoothing_speed * delta)
pos = cam.position.lerp(Vector2(target_x, target_y), t)

# ── 關卡邊界 clamp:一定放最後 ──
pos.x = clamp(pos.x, bounds.min_x + half_w, bounds.max_x - half_w)
pos.y = clamp(pos.y, bounds.min_y + half_h, bounds.max_y - half_h)

# ── 像素網格對齊(修訂 15),放在 clamp 之後 ──
if snap_camera_to_pixel:
    pos = (pos / float(render_divisor)).round() * float(render_divisor)

cam.position = pos
camera_moved.emit(pos)            # 3D 背景層的唯一輸入
```

**`snap_to_target()`(順帶 2)** — public,`_reset_all()` 與 `setup()` 都呼叫它:走同一套 target 計算與 clamp / 像素對齊,但**跳過死區與平滑**,直接寫入 `position` 並 emit。實作上把「算 target」與「clamp + snap + 寫入」拆成兩個私有函式,`_physics_process` 與 `snap_to_target()` 共用,避免兩份會走鐘的邏輯。

**四條規則怎麼被滿足**

1. **只有一個共用鏡頭** — GameViewport 裡只有這一個 `Camera2D`。
2. **永不把落後者推出畫面** — `target_x = trail_x` 讓落後者常駐中央。唯一可能推離他的是邊界 clamp;落後者必在 `[min_x, max_x]` 內,clamp 對鏡頭的位移上限就是 `half_w`,即最壞只推到畫面邊緣、不會出去。
3. **落後者到中央後才前進** — 鏡頭 x **只**由 `trail_x` 驅動。領先者往前跑不改變 `trail_x`,鏡頭不動。
4. **垂直跟隨 + clamp** — clamp 一律最後(先平滑再 clamp,否則平滑會把鏡頭帶出邊界)。

**行為後果**:固定 zoom 下,兩人距離超過 960 邏輯單位時**領先者會跑出畫面右緣**。只要有人得離開畫面,規格說了不能是落後者。這是規則 2+3 的必然結果,不是 bug。

### 修訂 15:鏡頭像素對齊(R7 的中間退路)

```gdscript
@export var snap_camera_to_pixel: bool = true
```

`snap_2d_transforms_to_pixel` 管的是物件相對於畫布;但鏡頭自己次像素移動時,**整個場景會相對像素網格漂移** — 那才是像素爬行的主因。把鏡頭釘在網格上通常能吃掉大部分問題,且與 snap 設定正交,兩個都開不衝突。

代價是鏡頭移動變階梯狀,d=4 時一階 = 1 渲染像素,肉眼看不出來。做成 export 開關,你實際看了再決定關不關。

---

## 3D 背景層與 2D 層的對應

**解析度**:兩個 SubViewport **都**是 `LOGICAL_SIZE / render_divisor`。低解析度 + 量化 + 抖動的視覺方向下,兩層像素大小不一致合成起來會很怪,共用網格是硬需求。

**位移縮放**:

```
cam3d.position.x =  cam2d_pos.x * world_units_per_pixel * parallax_factor
cam3d.position.y = -cam2d_pos.y * world_units_per_pixel * parallax_factor
```

| 參數 | 預設 | 意義 |
|---|---|---|
| `world_units_per_pixel` | 0.01 | 對**邏輯單位**:100 邏輯單位 ↔ 1 個 3D 單位 |
| `parallax_factor` | 0.15 | 背景以鏡頭 15% 速度移動 |
| `fov` | 60 | Camera3D 透視角 |

對邏輯單位定義,所以不隨 `render_divisor` 改變。

**y 軸一定要取負號** — 2D 的 y 向下為正,3D 的 y 向上為正。

深度分層免費:三層方塊放不同 `z`,透視投影本身讓遠的移動較少。用 `MeshInstance3D + BoxMesh`(不用 CSG:CSG 是啟動時 CPU 建構,網頁啟動已因 WASM 偏長)。

**WebGL2 限制**:不用 glow / SSAO / SDFGI / 體積霧,只用純色 clear + 單一 `DirectionalLight3D`。

---

## Input Map

**命名規則**:`p<n>_<verb>`,snake_case。

| Action | 按鍵 | physical_keycode |
|---|---|---|
| `p1_move_left` | A | 65 |
| `p1_move_right` | D | 68 |
| `p1_jump` | W | 87 |
| `p2_move_left` | ← | 4194319 |
| `p2_move_right` | → | 4194321 |
| `p2_jump` | ↑ | 4194320 |
| `debug_restart` | R | 82 |

keycode 取自 shadow-maze 的 `project.godot`(已驗證),連 `"device":16` 寫法沿用。

`player.gd` 用 `@export var input_prefix: StringName = &"p1"`,以 `"%s_move_left" % input_prefix` 組出 action — 一份腳本兩個實例。

**全部用 `Input` singleton 輪詢**(見架構約束)。

---

## project.godot 明確規格(N2 / N6)

v4 把這些壓縮成「renderer / stretch」兩個字,寫回具體值 — 這些每一條漏掉都會在**桌面正常、匯出才炸**的模式下失敗。

### 渲染器(N2)

```ini
[rendering]
renderer/rendering_method        = "gl_compatibility"
renderer/rendering_method.mobile = "gl_compatibility"
textures/canvas_textures/default_texture_filter = 0   # Nearest
2d/snap/snap_2d_transforms_to_pixel = true
2d/snap/snap_2d_vertices_to_pixel   = true
```

**不能默認。** Godot 4 預設是 **Forward+**,而 WebGL2 只有 `gl_compatibility` 一條路。沒寫死的話桌面會用 Forward+ 跑得好好的,直到步驟 7 匯出才炸 — 而那時 3D 背景的視覺已經照 Forward+ 調過一輪,得整個重調。

**連帶約束(綁在這個決策底下,寫進 dev-log)**:不用 glow / SSAO / SDFGI / 體積霧 / 螢幕空間反射。這不是「效能考量」,是 Compatibility 後端根本沒有。與 `test-my-nut/AGENTS.md`〈目標平台與效能考量〉最後一條一致。

### 視窗與縮放(N6)

```ini
[display]
window/size/viewport_width   = 1920
window/size/viewport_height  = 1080
window/size/window_width_override  = 1280      # 開發視窗
window/size/window_height_override = 720
window/stretch/mode   = "canvas_items"
window/stretch/aspect = "keep"
```

**`aspect` 必須是 `keep`,不能用 `expand`**:`expand` 會讓可視區隨視窗長寬比變動,與固定的 SubViewport 尺寸不符 → 畫面變形,而且 `half_w` 從此浮動,鏡頭數學不再是確定值(整個〈解析度架構〉的「恆為 960」就不成立了)。

### `main_scene`

```ini
[application]
run/main_scene = "res://scenes/main.tscn"
```

---

## 關卡資料與物理

`data/level_01.json`,約 12 筆平台(4 段地面、3 個缺口),x 跨 0 → 6720 **邏輯單位**(3.5 螢幕),高度從 y=1000 地面錯落到 y≈420。

```json
{
  "bounds":    { "min_x": 0, "max_x": 6720, "min_y": -600, "max_y": 1200 },
  "spawns":    [ { "x": 200, "y": 900 }, { "x": 340, "y": 900 } ],
  "platforms": [ { "x": 0, "y": 1000, "w": 1800, "h": 80 }, ... ]
}
```

物理常數(`player.gd` 的 `@export`,邏輯單位):`SPEED 420`、`JUMP_VELOCITY -1250`、`GRAVITY 2600`、`COYOTE_TIME 0.1`。玩家 **60×88**(88/4 = 22 整數;90 會得到 22.5)。

> 60×88 在 d ∈ {1,2,4} 下都是整數(60×88 / 30×44 / 15×22);d=3 得 20×29.33、d=6 得 10×14.67。跨所有 divisor 的整數尺寸不可能同時成立,這裡對預設 4 與最可能的 1、2 最佳化。

### 修訂 13:缺口斷言的單位定義

`level.gd` 載入時斷言相鄰同高地面的缺口 `<= MAX_GAP = 350`。**註解必須寫清楚以下推導**,否則之後調 `SPEED` 的人會用錯公式:

```gdscript
# 跳躍水平能力推導(全部是邏輯單位):
#   t_apex = |JUMP_VELOCITY| / GRAVITY = 1250 / 2600 = 0.481 s
#   t_air  = 2 * t_apex                              = 0.962 s
#   質心水平位移 = SPEED * t_air = 420 * 0.962        ≈ 404
#
# 但斷言的量是「邊緣間距」,不是質心位移。兩者差在:
#   +30  離開邊緣時質心在 edge + 半個碰撞箱寬(60/2)
#   +30  落地時質心只需到達 next_edge - 半個碰撞箱寬
#   +42  coyote time 允許離緣後再跳:SPEED * COYOTE_TIME = 420 * 0.1
#   邊緣到邊緣的理論極限 ≈ 404 + 60 + 42 = 506
#
# MAX_GAP = 350 是對 506 留約 31% 餘裕的保守值,吸收操作誤差。
# 斷言對象:next.x - (prev.x + prev.w),即邊緣間距。
const MAX_GAP := 350.0
```

`data/level_01.json` 的三個缺口都必須符合;不符就在載入時直接報錯,不讓過不去的關卡默默上線。

### 修訂 14:垂直可達性 — 印表人眼掃

現有斷言只管同高地面的水平缺口。跳躍高度約 300.5,關卡從 y=1000 排到 y≈420,若出現單段 320 的爬升,現有斷言抓不到。

這輪只有 12 個平台,**不寫完整可達性演算法**。`level.gd` 載入時把所有相鄰平台的 Δx / Δy 印成一張表,你人眼掃一遍:

```
idx  from        to          Δx      Δy    備註
 0   (   0,1000) ( 600, 820)  600  -180
 1   ( 600, 820) (1150, 640)  550  -180
 ...                                      ← Δy 超過 -300 會標記
```

超過跳躍高度的爬升加標記,方便你一眼看到。

### 修訂 5 + N4:`debug_restart` 與出界防護

`level.gd` 在 `_physics_process` **輪詢**(見架構約束 1)。**兩條路徑刻意不同**:

```
# R 鍵 —— 全域重置,回出生點
Input.is_action_just_pressed(&"debug_restart") → _reset_all()
_reset_all(): 兩人回出生點、velocity 歸零、
              camera.snap_to_target()(不平滑)

# 出界 —— 單人重生,回「最近的安全落腳點」(N4)
if player.global_position.y > bounds.max_y:
    player.global_position = player.last_grounded_position
    player.velocity = Vector2.ZERO
    # 鏡頭不 snap:落腳點就在附近,平滑跟過去即可
```

**為什麼出界不能回出生點(N4 的衝突)**

出界重生若送回 `x = 200`,會與鏡頭規則 2「永不把落後者推出畫面」直接打架:

> P2 在 `x = 3000` 掉坑 → 回 `x = 200` → `trail_x` 從 3000 瞬間變 200 → 鏡頭一路滑回開頭 → **還在 3000 的 P1 被丟出畫面**。

而且這不是鏡頭的錯 — 鏡頭忠實執行了規格,是重生點的選擇讓規格不可能被滿足。修重生點,不修鏡頭。

**`last_grounded_position`(Vector2)由 `player.gd` 維護**:每幀 `is_on_floor()` 為真就記下 `global_position`;**初始值 = 出生點**(順帶 1)。這一個欄位同時服務鏡頭的 `ref_y` 與這裡的重生,不開兩份。

代價是掉進坑裡會被放回坑緣、可能再掉一次 — 對原型而言比彈回開頭合理太多,而且不會破壞鏡頭規格。

**範圍界定 — 不是死亡重生系統**:沒有生命數、死亡動畫、計分、無敵時間、音效。約 20 行的邊界防護與重置。

---

## 檔案清單

### 新增 — 遊戲

| 檔案 | 職責 |
|---|---|
| `project.godot` | 見〈project.godot 明確規格〉+ 7 個 input action |
| `export_presets.cfg` | Web preset(no-threads,**無** custom feature tag,**`include_filter="*.json"`** ◀ N3) |
| `.gitignore` | 沿用 shadow-maze 那份,**外加 `build/`** |
| `AGENTS.md` | 移植 test-my-nut 慣例,**外加兩條架構約束:1「輸入一律輪詢」、2「初始化一律父推子」** |
| `scenes/main.tscn` | 合成樹結構 |
| `scenes/player.tscn` | CharacterBody2D prefab |
| `scenes/background_3d.tscn` | 3D 背景層內容 |
| `scripts/main.gd` | SubViewport 尺寸 / zoom / ViewportTexture / signal 接線 |
| `scripts/level.gd` | 讀 JSON → 生成平台;缺口斷言;落差表;restart 與出界防護 |
| `scripts/player.gd` | CharacterBody2D 控制器,`input_prefix` 區分玩家 |
| `scripts/shared_camera.gd` | 鏡頭演算法 |
| `scripts/background_3d.gd` | 視差驅動 + 可調參數 |
| `data/level_01.json` | 邊界、出生點、平台(1920×1080 邏輯尺度) |

### 新增 — 工具

| 檔案 | 職責 |
|---|---|
| `tools/serve.py` | **給你在瀏覽器看用的**,不是測試。靜態檔案 + port 8099 + 顯式 `.wasm`→`application/wasm`、`.pck`→`application/octet-stream` + 一律送 `Cache-Control: no-store`(避免重新匯出後 Chrome 拿到快取的舊 wasm 讓你誤判改動沒生效)。**不送 COOP/COEP** — no-threads 不需要,真要切 threads 再加 |
| `tools/install_export_templates.sh` | 冪等的範本安裝 |

**N3 — `data/level_01.json` 必須顯式列進 `include_filter`**

`FileAccess.open("res://data/level_01.json")` 在編輯器裡一定成功,因為原始檔就在磁碟上。匯出後不一定:非資源檔要在 export preset 的 `include_filter` 列出來才會進 `.pck`。症狀又是那個模式 — 桌面正常,匯出後載入失敗或整個關卡空白。

```ini
include_filter="*.json"
```

一行的保險。**不去賭 Godot 4 對 `.json` 的 import 行為** — 就算它真的被 import 成 `JSON` 資源,原始檔案是否保留在 pck 裡是另一回事,而我們讀的是原始檔案。

### 修改
- `README.md` — 操作說明、桌面與瀏覽器執行方式

### 開發日誌
- `development-log/2026-09-04-pseudo-2d-platformer-prototype.md` — **每個工作段落**記下做了什麼、遇到什麼、為什麼這樣決定。**邊做邊寫,不是最後補**,這是你後面追問題的依據。

  **第一段固定寫「計畫演進」**:v1 → v5 每一輪被駁回的理由與修正,重點是 N1–N6 這六項的**成因**(不只結論)。這些全都是「桌面正常 / 匯出才炸」或「不崩潰但靜靜地歪掉」型的問題,結論本身看起來像沒來由的規矩,理由不留下來,之後重構的人會把它們當成多餘的謹慎刪掉。

---

## 停點(auto 執行時必須停下來等回覆)

連續執行,但下列三處**停下來回報並等回覆**,不要自己往下走。

### 停點 1 — 落差表

`level.gd` 能載入 JSON 並印出相鄰平台的 Δx / Δy 表之後停,**整張表貼出來**。
修訂 14 的設計就是人眼掃,掃的人是 repo owner,不是我。

**缺口斷言 fail 的話一併貼出來,不自己去改 `level_01.json` 的座標。**
關卡幾何是設計決策,改座標等於替他做決定。

> 順序調整:`level.gd` 的載入與印表路徑拆到玩家控制器**之前**寫,
> 落差表不依賴 `player.gd`,停點 1 可以提早,不必等整個玩法層完成。

### 停點 2 — 桌面第一次跑起來

合成層與 3D 背景寫完、桌面能開之後停。回報:

- `activate()` 印出的 **`half_w` 實際值** — 應為 960;**若是 1024 表示 N1 有一步沒生效**
- `grim` 截圖
- 我自己觀察到的行為:兩人能不能各自動、鏡頭有沒有照落後者優先、3D 背景有沒有視差

**截圖交給 owner 判讀,我不下「通過」的結論**,只描述看到什麼。

### 停點 3 — 匯出到 Chrome 之後

匯出成功、`serve.py` 起來、頁面能開之後停,附截圖。

**R1 的失敗長得像成功**:`transparent_bg` 在 WebGL2 下失敗時畫面**不是全黑**,
而是 3D 層被 2D 層的黑底蓋掉 —— 看起來像「有畫面、能玩、只是背景是黑的」。
極容易誤判成通過,所以這張圖一定由 owner 看。

### 額外規則 — 偏離計畫就停

實際情況與 v5 不符時停下來回報,不自行判斷改法。包括但不限於:

- tpz 的 `unzip -l` 列出的成員名與預期不同
- 匯出範本安裝後版本對不上
- **任何一條斷言 fail**
- 需要改動 v5 已鎖定的決策(節點樹、鏡頭演算法、物理常數、renderer)

小的實作細節(變數命名、函式拆分、log 格式)自己決定,不用問。

---

## 實作順序

1. **開分支**,並**立刻在背景開始下載 1.19 GB 的 tpz**(下載期間繼續做別的事)
   ```bash
   flatpak update --user org.godotengine.Godot   # --user 必加,這台有 system+user 兩個 remote
   flatpak run org.godotengine.Godot --version   # 確認 4.7.2.stable
   ```
2. **dev-log 開檔**,先寫「計畫演進」第一段(N1–N6 的成因),再往下做
3. **專案骨架**:`project.godot`(依〈明確規格〉逐條寫)、`.gitignore`、`AGENTS.md`(含兩條架構約束)
4. **關卡資料與載入**:`level_01.json` → `level.gd` 的載入路徑 + 缺口斷言 + 落差表
   → **【停點 1】貼出落差表,等回覆**
5. **玩家**:`player.tscn`/`player.gd`(含 `last_grounded_position`)、`level.gd` 補上 `activate()` / 出界防護 / R 鍵
6. **鏡頭**:`shared_camera.gd`(`set_physics_process(false)` + `setup()` + `snap_to_target()`)
7. **合成層與 3D 背景**:`main.tscn`/`main.gd`(固定初始化順序)、`background_3d.tscn`/`background_3d.gd`
8. **桌面跑起來** + `grim` 截圖 + 印 `half_w`
   → **【停點 2】貼截圖與 `half_w`,等回覆**
9. **範本安裝完成後**:`export_presets.cfg` → 匯出 → `tools/serve.py` → Chrome 開起來 + 截圖
   → **【停點 3】貼截圖,等回覆(R1 / R2 由 owner 判讀)**
10. **README + dev-log 收尾**,交給你開始回報問題

範本下載與步驟 2–8 並行,不阻塞。

---

## 交付標準

做完的時候你應該能:

- `godot` 開起來,**兩個人各自用 WASD 和方向鍵跑跳**
- **鏡頭照落後者優先的規則走**
- **R 鍵能重置**(回出生點)
- **掉出界會被拉回** — 依 N4 改成「回最近的安全落腳點」,不是出生點。回出生點會把另一個玩家推出畫面,與鏡頭規則衝突
- **3D 背景有東西、會視差**

然後你開始回報問題。

---

## 已知風險

| # | 風險 | 應對 |
|---|---|---|
| **R1** | WebGL2 下 2D SubViewport 的 `transparent_bg` 若行為不如桌面 OpenGL,對稱雙 SubViewport 架構不成立 | 步驟 8 在 Chrome 確認。若壞掉,退回「只有 3D 進 SubViewport」分層 — 代價是失去 2D 層獨立濾鏡插槽,我會先回報再改 |
| **R2** | 方向鍵在瀏覽器預設捲動頁面,canvas 需先取得焦點。P2 綁方向鍵直接踩到 | 步驟 8 一併確認。**這輪不預先做任何處理**(N5:不做自訂 shell)。若真的中招,才做自訂 shell 加 `preventDefault()` 攔方向鍵 + 載入時 `canvas.focus()` — 我會先回報再動 |
| **R3** | 筆電鍵盤 **key rollover**:兩人同時按可能吃掉按鍵 | 硬體矩陣限制,程式面修不了。若發生:P2 改綁不同矩陣列按鍵,或用手把 |
| **R4** | 匯出範本版本不一致 → 匯出失敗 | `unzip -l` 先列實際成員名再解(4.3+ 起 no-threads 是獨立範本檔) |
| **R5** | 首次匯出因 `.godot/` 快取未建而失敗 | 匯出前先跑一次無頭載入建快取 |
| **R7** | `zoom != 1` 下 snap 設定是否真對齊,行為不明朗 | 修訂 15 的鏡頭網格對齊是中間退路。若仍有明顯爬行,把「像素完美」整個降級為這輪不做,**不臨時改架構** — 那是視覺瑕疵,不阻擋任何功能驗收 |
| **R8** | 手寫 `.tscn` / `export_presets.cfg` 文字出錯 | 桌面載入 + 匯出這兩步會直接暴露 |

**順帶記進 dev-log 的環境知識**(這輪用不到,但別弄丟):無頭 Chromium 從 **M139 起 WebGL context 建立會直接失敗**,若之後真要跑無頭瀏覽器必須加 `--enable-unsafe-swiftshader`,否則畫面全黑且症狀與架構失敗難以區分。

---

## 這輪不做

1. **任何美術素材** — 純色矩形 / 內建幾何
2. **音效與音樂**
3. **後製濾鏡本身** — 只留兩個 material 插槽,**不寫任何 shader**
4. **動態 zoom / 自動縮放框住兩人** — 因此領先者可能跑出畫面右緣
5. **分割畫面**
6. **玩家之間的互動** — 不能踩頭、推擠、舉起對方
7. **單向平台 / 可穿越平台 / 下墜穿越**
8. **移動平台、機關、危險物**
9. **死亡系統** — 無生命數、死亡動畫、無敵時間、計分。**出界防護與 R 鍵重置有做**,那是邊界防護不是死亡系統
10. **進階手感** — jump buffer、可變跳躍高度、加減速曲線都不做;**只做 coyote time**
11. **遊戲流程** — 開始畫面、暫停、關卡切換、過關條件、UI/HUD
12. **存檔 / 設定選單 / 按鍵重新綁定**
13. **手把支援** — 只做鍵盤
14. **網路 / 多人連線**
15. **3D 背景的動態內容** — 無動畫、粒子、天空盒、動態光照
16. **效能優化** — 無視錐剔除、LOD、物件池
17. **完整的垂直可達性演算法** — 只印落差表給人眼掃(修訂 14)
18. **自動化測試** — 無 Playwright、無斷言腳本、無 headless 驗證腳本。你自己跑自己回報
19. **自訂 HTML shell — 完全不做**(N5)。用 Godot 內建的 shell,`image-rendering: pixelated` 也不加。步驟 7 的目的只是驗證 R1 / R2,browser 裡糊一點不影響判斷;而 R2 真的中招時本來就得動這個 shell,到時再一起做。檔案清單裡沒有 HTML shell,`export_presets.cfg` 也不指過去 — **不留半個承諾**
20. **threads 模式的 Web 匯出** — 預設 no-threads
21. **正式部署 / CI** — 只跑本機 `serve.py`
22. **`git commit` / `git push`** — 依 AGENTS.md 一律由你手動執行

## 暫時不處理

- **Safari / macOS / iOS 相容性** — Linux 上無法驗證,這輪跳過
