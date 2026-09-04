extends Node2D
## 關卡:讀 JSON、生成平台與玩家、驗證幾何、每幀處理重置與出界防護。
##
## 架構約束 2(見 AGENTS.md):_ready() 只做「讀 JSON → 生節點 → 算 bounds」,
## 完全不碰鏡頭。鏡頭要等 Main._ready() 把 SubViewport 尺寸與 zoom 都設好之後
## 呼叫 activate() 才放行——否則鏡頭會用 512x512 / zoom 0.25 算出 half_w = 1024。

const LEVEL_PATH := "res://data/level_01.json"

## 跳躍水平能力推導(全部是邏輯單位):
##   t_apex = |JUMP_VELOCITY| / GRAVITY = 1250 / 2600 = 0.481 s
##   t_air  = 2 * t_apex                              = 0.962 s
##   質心水平位移 = SPEED * t_air = 420 * 0.962        ≈ 404
##
## 但斷言的量是「邊緣間距」,不是質心位移。兩者差在:
##   +30  離開邊緣時質心在 edge + 半個碰撞箱寬(60/2)
##   +30  落地時質心只需到達 next_edge - 半個碰撞箱寬
##   +42  coyote time 允許離緣後再跳:SPEED * COYOTE_TIME = 420 * 0.1
##   邊緣到邊緣的理論極限 ≈ 404 + 60 + 42 = 506
##
## MAX_GAP = 350 是對 506 留約 31% 餘裕的保守值,吸收操作誤差。
## 斷言對象:next.x - (prev.x + prev.w),即邊緣間距。
const MAX_GAP := 350.0

## 跳躍高度 = JUMP_VELOCITY^2 / (2 * GRAVITY) = 1250^2 / 5200 ≈ 300.5
## 只用來在落差表上標記「這段爬升超過跳躍高度」,不做斷言(修訂 14:人眼掃)。
const JUMP_HEIGHT := 300.5

const PLATFORM_COLOR := Color(0.30, 0.34, 0.42)
const PLAYER_COLORS: Array[Color] = [
	Color(0.90, 0.38, 0.32),   # P1 — WASD
	Color(0.36, 0.70, 0.92),   # P2 — 方向鍵
]

var bounds: Rect2
var spawn_points: Array[Vector2] = []
var platform_data: Array[Dictionary] = []

var _players: Array[Player] = []

@onready var _platforms_root: Node2D = $Platforms
@onready var _camera: SharedCamera = $SharedCamera


func _ready() -> void:
	var data := _load_level_data(LEVEL_PATH)
	if data.is_empty():
		push_error("[Level] 關卡載入失敗,場景不會被建立")
		return

	_parse_bounds(data)
	_parse_spawns(data)
	_parse_platforms(data)

	_print_platform_table()
	_validate_gaps(data)

	_build_platforms()
	_place_players()


# ──────────────────────────────────────────────────────────────
# 載入與解析(純函式,不依賴場景樹,方便 headless 驗證直接呼叫)
# ──────────────────────────────────────────────────────────────

func _load_level_data(path: String) -> Dictionary:
	# 讀原始檔案而非 load() 成 JSON 資源 —— 因此 export_presets.cfg 的
	# include_filter 必須含 "*.json",否則匯出後這裡會失敗(N3)。
	if not FileAccess.file_exists(path):
		push_error("[Level] 找不到關卡檔:%s" % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[Level] 無法開啟關卡檔:%s(err %d)" % [path, FileAccess.get_open_error()])
		return {}

	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[Level] 關卡檔不是合法的 JSON 物件:%s" % path)
		return {}

	return parsed as Dictionary


func _parse_bounds(data: Dictionary) -> void:
	var b: Dictionary = data.get("bounds", {})
	var min_x := float(b.get("min_x", 0.0))
	var min_y := float(b.get("min_y", 0.0))
	var max_x := float(b.get("max_x", 0.0))
	var max_y := float(b.get("max_y", 0.0))
	bounds = Rect2(min_x, min_y, max_x - min_x, max_y - min_y)


func _parse_spawns(data: Dictionary) -> void:
	spawn_points.clear()
	for entry: Variant in data.get("spawns", []):
		var s: Dictionary = entry
		spawn_points.append(Vector2(float(s.get("x", 0.0)), float(s.get("y", 0.0))))


func _parse_platforms(data: Dictionary) -> void:
	platform_data.clear()
	for entry: Variant in data.get("platforms", []):
		var p: Dictionary = entry
		platform_data.append({
			"name": String(p.get("name", "Platform")),
			"x": float(p.get("x", 0.0)),
			"y": float(p.get("y", 0.0)),
			"w": float(p.get("w", 0.0)),
			"h": float(p.get("h", 0.0)),
		})
	platform_data.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["x"]) < float(b["x"]))


# ──────────────────────────────────────────────────────────────
# 幾何驗證
# ──────────────────────────────────────────────────────────────

## 修訂 14:把相鄰平台的 Δx / Δy 印成表給人眼掃。
## 這輪只有 12 個平台,刻意不寫完整的可達性演算法。
func _print_platform_table() -> void:
	print("")
	print("=== 相鄰平台落差表(x 排序;x=左緣, y=上緣/踩踏面)===")
	print("  跳躍高度 ≈ %.1f,MAX_GAP = %.0f(邊緣間距)" % [JUMP_HEIGHT, MAX_GAP])
	print("")
	print("  idx  name       from(x,y)        to(x,y)          邊緣Δx    Δy   備註")
	for i: int in range(platform_data.size() - 1):
		var a: Dictionary = platform_data[i]
		var b: Dictionary = platform_data[i + 1]
		var edge_gap := float(b["x"]) - (float(a["x"]) + float(a["w"]))
		var dy := float(b["y"]) - float(a["y"])

		var notes: Array[String] = []
		if edge_gap < 0.0:
			notes.append("水平重疊")
		if dy < -JUMP_HEIGHT:
			notes.append("爬升 %.0f > 跳躍高度" % absf(dy))
		if edge_gap > MAX_GAP:
			notes.append("邊緣間距 > MAX_GAP")

		print("  %3d  %-9s (%5.0f,%5.0f) -> (%5.0f,%5.0f)  %7.0f  %5.0f   %s" % [
			i,
			String(a["name"]),
			float(a["x"]), float(a["y"]),
			float(b["x"]), float(b["y"]),
			edge_gap, dy,
			", ".join(notes),
		])
	print("")


## 斷言:同高「地面」列的相鄰缺口不得超過 MAX_GAP。
##
## 只斷言地面列(y == ground_y),不斷言浮空平台。理由:地面列的缺口是
## 必經之路,過不去就卡關;浮空平台之間的空隙是可選路線,兩塊同高但相隔
## 很遠的浮空平台不代表有誰得跳過去。
func _validate_gaps(data: Dictionary) -> void:
	var ground_y := float(data.get("ground_y", 0.0))
	var ground_row: Array[Dictionary] = []
	for p: Dictionary in platform_data:
		if is_equal_approx(float(p["y"]), ground_y):
			ground_row.append(p)

	print("=== 地面列缺口斷言(ground_y = %.0f,共 %d 段)===" % [ground_y, ground_row.size()])
	var failures := 0
	for i: int in range(ground_row.size() - 1):
		var a: Dictionary = ground_row[i]
		var b: Dictionary = ground_row[i + 1]
		var edge_gap := float(b["x"]) - (float(a["x"]) + float(a["w"]))
		var ok := edge_gap <= MAX_GAP
		if not ok:
			failures += 1
		print("  %-9s -> %-9s  缺口 %6.1f  /  上限 %.0f   %s" % [
			String(a["name"]), String(b["name"]), edge_gap, MAX_GAP,
			"OK" if ok else "*** FAIL ***",
		])

	if failures > 0:
		push_error("[Level] %d 個地面缺口超過 MAX_GAP=%.0f,關卡過不去" % [failures, MAX_GAP])
	else:
		print("  全部通過。")
	print("")


# ──────────────────────────────────────────────────────────────
# 場景建構
# ──────────────────────────────────────────────────────────────

func _build_platforms() -> void:
	for p: Dictionary in platform_data:
		_platforms_root.add_child(_make_platform(p))


func _make_platform(p: Dictionary) -> StaticBody2D:
	var w := float(p["w"])
	var h := float(p["h"])
	var size := Vector2(w, h)

	var body := StaticBody2D.new()
	body.name = String(p["name"])
	# JSON 的 x/y 是左上角;StaticBody2D 以中心定位。
	body.position = Vector2(float(p["x"]) + w * 0.5, float(p["y"]) + h * 0.5)
	body.collision_layer = 1
	body.collision_mask = 0

	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	body.add_child(col)

	# ColorRect 從左上角定位,CollisionShape2D 從中心 —— 差一個 -size/2。
	var rect := ColorRect.new()
	rect.size = size
	rect.position = -size * 0.5
	rect.color = PLATFORM_COLOR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(rect)

	return body


func _place_players() -> void:
	_players = [$Player1 as Player, $Player2 as Player]
	for i: int in _players.size():
		var p: Player = _players[i]
		if i < spawn_points.size():
			# 用 teleport_to() 而不是直接寫 position ——
			# Player._ready() 早於 Level._ready()(架構約束 2),那時它已經
			# 把 last_grounded_position 設成 .tscn 裡的位置了。teleport_to()
			# 會一併更新,直接寫 position 不會,鏡頭的垂直參考點就會留在舊值。
			p.teleport_to(spawn_points[i])
		# 用方法而不是直接寫 body_color:Player._ready() 已經跑完了,
		# 再寫那個 export 只會改到變數,ColorRect 不會跟著更新。
		p.set_body_color(PLAYER_COLORS[i % PLAYER_COLORS.size()])


# ──────────────────────────────────────────────────────────────
# 啟動與每幀
# ──────────────────────────────────────────────────────────────

## 由 Main._ready() 呼叫 —— 不是在 _ready() 裡自己跑。
##
## 架構約束 2:Level._ready() 早於 Main._ready(),此時 SubViewport 還是預設
## 512x512、相機 zoom 還是 .tscn 裡的值。鏡頭若在那個時間點算 half_w 會得到
## 1024 而不是 960,而且不會崩潰,只會「邊界怪怪的」。所以放行的時機必須由
## 最後 _ready() 的 Main 決定。
func activate() -> void:
	var initial_pos := _initial_camera_position()
	_camera.setup(bounds, initial_pos, _players[0], _players[1])
	print("[Level] activate:bounds=%s initial_cam=%s" % [bounds, initial_pos])


func _initial_camera_position() -> Vector2:
	if spawn_points.is_empty():
		return bounds.get_center()
	var trail_x := spawn_points[0].x
	var sum_y := 0.0
	for s: Vector2 in spawn_points:
		trail_x = minf(trail_x, s.x)
		sum_y += s.y
	return Vector2(trail_x, sum_y / float(spawn_points.size()))


func _physics_process(_delta: float) -> void:
	# 架構約束 1:一律輪詢 Input singleton。
	# 這個節點在裸掛的 SubViewport 底下,_unhandled_input() 永遠不會被呼叫。
	if Input.is_action_just_pressed(&"debug_restart"):
		_reset_all()

	_guard_out_of_bounds()


## R 鍵:兩人回出生點,鏡頭直接 snap(不平滑)。
func _reset_all() -> void:
	for i: int in _players.size():
		if i < spawn_points.size():
			_players[i].teleport_to(spawn_points[i])
	_camera.snap_to_target()
	print("[Level] 重置")


## 出界防護:掉到 bounds 下緣以外就送回「最近的安全落腳點」。
##
## N4 —— 刻意不送回出生點。鏡頭是 trail_x = min(p1.x, p2.x) 驅動的,
## 把落後的人瞬移回起點會讓 trail_x 暴跌,鏡頭一路滑回開頭,還在前面的
## 另一個玩家就被推出畫面 —— 直接違反「永不把落後者推出畫面」。
## 那不是鏡頭的錯,是重生點的選擇讓規格不可能被滿足,所以修重生點。
func _guard_out_of_bounds() -> void:
	var floor_y := bounds.end.y
	for p: Player in _players:
		if p.global_position.y > floor_y:
			p.teleport_to(p.last_grounded_position)
