extends Node2D
class_name Level
## 關卡:讀 JSON、生成兩個空間的平台與拾取物、驗證幾何、每幀處理切換與重置。
##
## 架構約束 2(見 AGENTS.md):_ready() 只做「讀 JSON → 生節點 → 算 bounds」,
## 完全不碰鏡頭、也不發 space_changed。鏡頭與訊號要等 Main._ready() 把
## SubViewport 尺寸、zoom、訊號接線都做完之後呼叫 activate() 才放行——
## 否則鏡頭會用 512x512 / zoom 0.25 算出 half_w = 1024,而第一次 space_changed
## 會在沒有人接的時候發出去。

## 空間切換發生時通知外層(目前只有 3D 背景在聽)。
## 傳 StringName 而不是 enum:背景層不需要認識這個腳本的型別,
## 兩層的解耦就是靠這個單向、無型別依賴的訊號。
signal space_changed(space: StringName)

const LEVEL_PATH := "res://data/level_01.json"

## 空間。**整個關卡的空間狀態只有 _active_space 一個變數是真相**,
## 玩家的 mask、平台的顏色與透明度、背景的訊號全部由 _apply_space() 推導。
## (AGENTS.md:同一份狀態不要開兩個欄位)
const SPACE_NORMAL := &"normal"
const SPACE_ALT := &"alt"
const SPACE_BOTH := &"both"

## 兩個空間各佔一個 collision layer,而且**平台的 layer 設定一次之後永不改變**。
## 切換空間改的是「兩個玩家的 collision_mask」。這樣做有三個理由:
##   1. 兩個空間永遠都查得到 → 切換前的卡牆預檢才有東西可查
##   2. 空間狀態只有一份,不會走鐘
##   3. 完全不用改 player.gd / player.tscn —— collision_mask 是
##      CharacterBody2D 的內建屬性,由這裡直接寫(架構約束 2:父推子)
## bit 2(值 2)是玩家自己的 layer,見 scenes/player.tscn,這裡不動它。
const LAYER_NORMAL := 1
const LAYER_ALT := 4
const LAYER_PLAYER := 2

## 卡牆預檢用的收縮量。查詢矩形比碰撞箱小這麼多,
## 避免「剛好貼著平台站著」被浮點誤差誤判成重疊。
const SWITCH_QUERY_MARGIN := 2.0

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
const MAX_GAP := 350.0

## 跳躍高度 = JUMP_VELOCITY^2 / (2 * GRAVITY) = 1250^2 / 5200 ≈ 300.5
## 只用來在落差表上標記「這段爬升超過跳躍高度」,不做斷言(人眼掃)。
const JUMP_HEIGHT := 300.5

## 三種平台各一個顏色。both 給第三個色相而不是跟著作用空間走 ——
## 「這塊永遠踩得到」是玩家最需要一眼認出來的資訊。
##
## 三個都刻意比 3D 背景亮一截:背景那層是大塊的方塊,亮度落在 0.2~0.35,
## 玩法幾何如果跟它同一個亮度帶,跑酷段就會分不出哪塊踩得到 —— 實測截圖
## 就是這樣。**用亮度把兩層分開,用色相區分三種平台。**
## (這是草稿值,不好看直接改這三個常數,不會影響任何邏輯)
const COLOR_NORMAL := Color(0.50, 0.58, 0.72)
const COLOR_ALT := Color(0.68, 0.45, 0.78)
const COLOR_BOTH := Color(0.62, 0.58, 0.50)
## 非作用空間的平台維持可見但半透明。**這不是裝飾** ——
## 沒有幽靈預覽就是閉著眼睛跳,切換機制不成立。
## 0.22 實測太低:背景一忙就完全看不見那塊幽靈。
const GHOST_ALPHA := 0.38

const COLOR_GOGGLES := Color(0.95, 0.80, 0.25)
const COLOR_KEY := Color(0.95, 0.55, 0.20)

## 兩個玩家共用同一份貓貼圖,靠 modulate 相乘染色區分。
## P1 用白色 = 不染,保留美術原色;P2 染藍,沿用舊配色裡的那個藍。
## 相乘染色在黑貓身上只吃得到亮部(連帽衫、球鞋、墨鏡),黑色身體不受影響 ——
## 這反而是好事:兩隻貓的剪影一致,只有配色不同。
const PLAYER_TINTS: Array[Color] = [
	Color.WHITE,               # P1 — 原色
	Color(0.45, 0.72, 1.00),   # P2 — 染藍
]

var bounds: Rect2
var spawn_points: Array[Vector2] = []
var platform_data: Array[Dictionary] = []
var pickup_data: Array[Dictionary] = []

var _players: Array[Player] = []
## 與 platform_data / pickup_data 同索引。
var _platform_bodies: Array[StaticBody2D] = []
var _pickup_areas: Array[Area2D] = []

var _active_space: StringName = SPACE_NORMAL
## 護目鏡的持有者索引,-1 = 還沒有人撿到。切換權只屬於他。
## 不另外開一個 _goggles_taken:那會是同一份狀態的第二個欄位。
var _goggles_holder: int = -1
var _key_taken: bool = false

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
	_parse_pickups(data)

	# 兩個報表共用同一份「哪些 x 區間沒有落腳面」的計算,不各算一次 ——
	# 各算一次的話落差表會說出跟斷言矛盾的話(牆疊在地板上時尤其明顯)。
	var uncovered := _compute_uncovered_spans()
	_print_platform_table(uncovered)
	_validate_reachability(uncovered)

	_build_platforms()
	_build_pickups()
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
			# 缺 space 欄位時當 both。漏寫不會靜靜地走鐘 ——
			# 落差表有 space 欄,漏寫的那一列會直接顯示 both。
			"space": StringName(p.get("space", SPACE_BOTH)),
			"x": float(p.get("x", 0.0)),
			"y": float(p.get("y", 0.0)),
			"w": float(p.get("w", 0.0)),
			"h": float(p.get("h", 0.0)),
		})
	platform_data.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["x"]) < float(b["x"]))


## 拾取物的 x/y 是**中心**(跟 spawns 一致,跟平台的左上角不一致)。
## 這個不一致寫在 level_01.json 的 _comment 裡。
func _parse_pickups(data: Dictionary) -> void:
	pickup_data.clear()
	for entry: Variant in data.get("pickups", []):
		var p: Dictionary = entry
		pickup_data.append({
			"name": String(p.get("name", "Pickup")),
			"kind": StringName(p.get("kind", "")),
			"x": float(p.get("x", 0.0)),
			"y": float(p.get("y", 0.0)),
			"w": float(p.get("w", 48.0)),
			"h": float(p.get("h", 48.0)),
		})


# ──────────────────────────────────────────────────────────────
# 幾何驗證
# ──────────────────────────────────────────────────────────────

## 把相鄰平台的 Δx / Δy 印成表給人眼掃,多一個 space 欄。
##
## 「需切換」這個標記只在**這段 x 真的沒有任何落腳面**時才打 ——
## 判斷依據是傳進來的 uncovered,跟下面的斷言同一份資料。
## 不這樣做的話,牆疊在地板上時(RoomWallL/R 在 RoomFloor 的 x 範圍內)
## 表格會把兩面牆之間報成 980 的缺口,而那段地板明明是連續的。
func _print_platform_table(uncovered: Array[Vector2]) -> void:
	print("")
	print("=== 相鄰平台落差表(x 排序;x=左緣, y=上緣/踩踏面)===")
	print("  跳躍高度 ≈ %.1f,MAX_GAP = %.0f(邊緣間距)" % [JUMP_HEIGHT, MAX_GAP])
	print("")
	print("  idx  name       space   from(x,y)        to(x,y)          邊緣Δx    Δy   備註")
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
		if edge_gap > 0.0 and _is_uncovered(float(a["x"]) + float(a["w"]), float(b["x"]), uncovered):
			var space_a: StringName = a["space"]
			var space_b: StringName = b["space"]
			if _spaces_overlap(space_a, space_b) and edge_gap > MAX_GAP:
				notes.append("同空間跨不過 → 需切換")
			elif not _spaces_overlap(space_a, space_b):
				notes.append("異空間,靠切換銜接")

		print("  %3d  %-9s %-6s  (%5.0f,%5.0f) -> (%5.0f,%5.0f)  %7.0f  %5.0f   %s" % [
			i,
			String(a["name"]), String(a["space"]),
			float(a["x"]), float(a["y"]),
			float(b["x"]), float(b["y"]),
			edge_gap, dy,
			", ".join(notes),
		])
	print("")


## 把**所有**平台(不分空間)在 x 軸上的投影取聯集,回傳中間沒被覆蓋到的
## 區間,每個是一個 Vector2(start, end)。落差表與斷言共用這一份結果。
##
## 為什麼是「不分空間」:這一關的柱子間隔故意做到 620,遠大於 MAX_GAP ——
## **單一空間走不通正是設計意圖**,對單空間算只會得到一堆假缺口。真正會卡死
## 的是「兩個空間都沒有東西可踩」,這個函式算的就是它。
func _compute_uncovered_spans() -> Array[Vector2]:
	var spans: Array[Vector2] = []
	for p: Dictionary in platform_data:
		var left := float(p["x"])
		spans.append(Vector2(left, left + float(p["w"])))
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	var holes: Array[Vector2] = []
	if spans.is_empty():
		return holes

	var covered_to := spans[0].y
	for i: int in range(1, spans.size()):
		var s := spans[i]
		if s.x > covered_to:
			holes.append(Vector2(covered_to, s.x))
		covered_to = maxf(covered_to, s.y)
	return holes


## 硬斷言只有一條:沒有任何一段「兩個空間都沒有落腳面」的 x 區間超過 MAX_GAP。
##
## 兩個已知的寬鬆處,寫出來而不是假裝沒有:
##   1. 牆(高而窄、踩不到頂的平台)也會貢獻 x 覆蓋,所以有牆的區段這條會比
##      實際寬鬆。這一關的牆都站在地板上,地板本身已經覆蓋那段 x。
##   2. 垂直方向不斷言 —— 這條刻意不假裝是完整的可達性演算法
##      (plan-v5〈這輪不做〉#17),爬升靠上面那張表給人眼掃。
func _validate_reachability(uncovered: Array[Vector2]) -> void:
	print("=== 跨空間 x 投影聯集斷言(上限 %.0f)===" % MAX_GAP)
	if platform_data.is_empty():
		push_error("[Level] 關卡沒有任何平台")
		print("")
		return

	var failures := 0
	for hole: Vector2 in uncovered:
		var gap := hole.y - hole.x
		var ok := gap <= MAX_GAP
		if not ok:
			failures += 1
		print("  x %7.0f -> %7.0f   無落腳面 %6.1f   %s" % [
			hole.x, hole.y, gap, "OK" if ok else "*** FAIL ***"])

	if failures > 0:
		push_error("[Level] %d 段 x 區間兩個空間都沒有落腳面且超過 MAX_GAP=%.0f,關卡過不去" % [
			failures, MAX_GAP])
	else:
		print("  全部通過(%d 段無落腳面區間,最寬 %.0f)。" % [
			uncovered.size(), _widest_hole(uncovered)])
	print("")


func _widest_hole(uncovered: Array[Vector2]) -> float:
	var widest := 0.0
	for hole: Vector2 in uncovered:
		widest = maxf(widest, hole.y - hole.x)
	return widest


## 這一段 x 是不是真的沒有落腳面。落差表用它來決定要不要標「需切換」——
## 兩塊平台之間看起來有缺口,不代表那段沒有別的平台墊著。
func _is_uncovered(from_x: float, to_x: float, uncovered: Array[Vector2]) -> bool:
	for hole: Vector2 in uncovered:
		if from_x >= hole.x - 0.5 and to_x <= hole.y + 0.5:
			return true
	return false


# ──────────────────────────────────────────────────────────────
# 場景建構
# ──────────────────────────────────────────────────────────────

func _build_platforms() -> void:
	_platform_bodies.clear()
	for p: Dictionary in platform_data:
		var body := _make_platform(p)
		_platform_bodies.append(body)
		_platforms_root.add_child(body)


func _make_platform(p: Dictionary) -> StaticBody2D:
	var w := float(p["w"])
	var h := float(p["h"])
	var size := Vector2(w, h)
	var space: StringName = p["space"]

	var body := StaticBody2D.new()
	body.name = String(p["name"])
	# JSON 的 x/y 是左上角;StaticBody2D 以中心定位。
	body.position = Vector2(float(p["x"]) + w * 0.5, float(p["y"]) + h * 0.5)
	# layer 設一次就不再改。切換空間改的是玩家的 mask,不是這裡。
	body.collision_layer = _space_layers(space)
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
	rect.color = _space_color(space)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(rect)

	return body


func _build_pickups() -> void:
	_pickup_areas.clear()
	for i: int in pickup_data.size():
		var area := _make_pickup(pickup_data[i], i)
		_pickup_areas.append(area)
		_platforms_root.add_child(area)


## 拾取物不分空間:護目鏡在正常空間的房間裡、鑰匙在異空間的碎片盡頭,
## 玩家本來就只可能在對的空間走到它們面前,再加一個 space 欄位不會驅動
## 任何行為(AGENTS.md:不要留誤導性的死欄位)。
func _make_pickup(p: Dictionary, index: int) -> Area2D:
	var size := Vector2(float(p["w"]), float(p["h"]))

	var area := Area2D.new()
	area.name = String(p["name"])
	# 拾取物的 x/y 是中心,不像平台是左上角。
	area.position = Vector2(float(p["x"]), float(p["y"]))
	area.collision_layer = 0
	area.collision_mask = LAYER_PLAYER

	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	area.add_child(col)

	var kind: StringName = p["kind"]
	var rect := ColorRect.new()
	rect.size = size
	rect.position = -size * 0.5
	rect.color = _pickup_color(kind)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(rect)

	# body_entered 是物理訊號,**不受架構約束 1 影響** ——
	# 那條限制的是輸入回呼(_input / _unhandled_input / _gui_input),
	# 物理訊號在裸掛的 SubViewport 底下照常運作。
	area.body_entered.connect(_on_pickup_body_entered.bind(index))
	return area


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
		# 用方法而不是直接寫 tint:Player._ready() 已經跑完了,
		# 再寫那個 export 只會改到變數,AnimatedSprite2D 不會跟著更新。
		p.set_tint(PLAYER_TINTS[i % PLAYER_TINTS.size()])


# ──────────────────────────────────────────────────────────────
# 啟動與每幀
# ──────────────────────────────────────────────────────────────

## 由 Main._ready() 呼叫 —— 不是在 _ready() 裡自己跑。
##
## 架構約束 2:Level._ready() 早於 Main._ready(),此時 SubViewport 還是預設
## 512x512、相機 zoom 還是 .tscn 裡的值,而且 space_changed 還沒有人接。
## 鏡頭若在那個時間點算 half_w 會得到 1024 而不是 960,而且不會崩潰,
## 只會「邊界怪怪的」。所以放行的時機必須由最後 _ready() 的 Main 決定。
func activate() -> void:
	var initial_pos := _initial_camera_position()
	_camera.setup(bounds, initial_pos, _players[0], _players[1])
	# 第一次同步空間狀態必須在這裡,不能在 _ready() ——
	# _apply_space() 會發 space_changed,而接線是 Main._ready() 才做的。
	_apply_space()
	_refresh_pickups()
	print("[Level] activate:bounds=%s initial_cam=%s space=%s" % [
		bounds, initial_pos, _active_space])


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
		# R 是除錯鍵,清得比出界徹底 —— 要能重測開場那段。
		_reset_all("R 鍵", true)
		return

	_poll_space_toggle()
	_guard_out_of_bounds()


# ──────────────────────────────────────────────────────────────
# 空間切換
# ──────────────────────────────────────────────────────────────

## 只有拿到護目鏡的那個人能切換 —— 對應「一名玩家撿起護目鏡,啟動之後會變成
## 異世界」。另一個人按自己的切換鍵不會有任何反應,這是刻意的。
func _poll_space_toggle() -> void:
	if _goggles_holder < 0:
		return
	var action := StringName("p%d_toggle_space" % (_goggles_holder + 1))
	if Input.is_action_just_pressed(action):
		_try_toggle_space()


func _try_toggle_space() -> void:
	var target: StringName = SPACE_ALT if _active_space == SPACE_NORMAL else SPACE_NORMAL
	var blocker := _find_switch_blocker(_space_layers(target))
	if blocker >= 0:
		print("[Level] 切換被擋下:P%d 在「%s」空間會卡進實體裡" % [blocker + 1, target])
		return

	# 記下切換當下兩人的落地狀態:整個世界一起翻的時候,站在「只存在於
	# 舊空間」的平台上的人腳下會直接沒東西。這一行是那件事的直接證據。
	var footing := "P1 %s / P2 %s" % [
		"在地上" if _players[0].is_on_floor() else "空中",
		"在地上" if _players[1].is_on_floor() else "空中"]
	_active_space = target
	_apply_space()
	print("[Level] 切換空間 -> %s(%s)" % [_active_space, footing])


## 站在「另一個空間有實體」的位置上切換會卡進幾何裡。處置是**擋下切換**,
## 不是切了再讓物理把人推出來 —— 那會把人彈到奇怪的地方,而且是靜默的。
##
## 只擋「會卡進實體」,不擋「腳下的地板會消失」—— 後者是這個機制的核心風險,
## 玩家要自己承擔。
##
## 回傳擋路的玩家索引,沒有就回 -1。
func _find_switch_blocker(target_layer: int) -> int:
	var space_state := get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	params.collision_mask = target_layer
	params.collide_with_bodies = true
	params.collide_with_areas = false

	for i: int in _players.size():
		var p: Player = _players[i]
		var box := _player_query_shape(p)
		if box == null:
			continue
		params.shape = box
		params.transform = Transform2D(0.0, p.global_position)
		if not space_state.intersect_shape(params, 1).is_empty():
			return i
	return -1


## 查詢矩形從玩家自己的 CollisionShape2D 讀出來,**不寫死 60x88** ——
## 那會變成碰撞箱尺寸的第二份拷貝,改了 player.tscn 這裡會靜靜地走鐘。
## 縮 SWITCH_QUERY_MARGIN 是為了讓「剛好貼著平台站著」不被浮點誤差
## 誤判成重疊。
func _player_query_shape(p: Player) -> RectangleShape2D:
	var col := p.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if col == null:
		push_error("[Level] 玩家底下找不到 CollisionShape2D,切換空間的卡牆預檢失效")
		return null
	var rect := col.shape as RectangleShape2D
	if rect == null:
		push_error("[Level] 玩家的碰撞形狀不是 RectangleShape2D,切換空間的卡牆預檢失效")
		return null
	var shrunk := RectangleShape2D.new()
	shrunk.size = rect.size - Vector2.ONE * (SWITCH_QUERY_MARGIN * 2.0)
	return shrunk


## **空間狀態的唯一出口。** _active_space 是真相,這裡把它推導成:
## 玩家的 mask、平台的透明度、以及對外的訊號。其他地方不得自己維護一份。
func _apply_space() -> void:
	var mask := _space_layers(_active_space)
	for p: Player in _players:
		p.collision_mask = mask

	for i: int in _platform_bodies.size():
		var space: StringName = platform_data[i]["space"]
		var solid := _spaces_overlap(space, _active_space)
		_platform_bodies[i].modulate.a = 1.0 if solid else GHOST_ALPHA

	space_changed.emit(_active_space)


# ──────────────────────────────────────────────────────────────
# 拾取物與關卡狀態
# ──────────────────────────────────────────────────────────────

func _on_pickup_body_entered(body: Node2D, index: int) -> void:
	var player := body as Player
	if player == null:
		return

	var kind: StringName = pickup_data[index]["kind"]
	if _is_taken(kind):
		return

	match kind:
		&"goggles":
			_goggles_holder = _players.find(player)
			print("[Level] P%d 撿到護目鏡 —— 切換空間解鎖" % (_goggles_holder + 1))
		&"key":
			_key_taken = true
			print("[Level] 鑰匙到手。(現階段範圍:撿到就到此為止,崩塌與過關是下一輪)")
		_:
			push_warning("[Level] 不認得的 pickup kind:%s" % kind)
			return

	_refresh_pickups()


func _is_taken(kind: StringName) -> bool:
	match kind:
		&"goggles":
			return _goggles_holder >= 0
		&"key":
			return _key_taken
	return false


## 拾取物節點是關卡狀態的「畫面」,不是狀態本身 —— 撿沒撿到只存在
## _goggles_holder / _key_taken 裡,節點每次從那兩個變數重繪。
## 重置時因此不必逐一記得要復原什麼。
func _refresh_pickups() -> void:
	for i: int in _pickup_areas.size():
		var kind: StringName = pickup_data[i]["kind"]
		var taken := _is_taken(kind)
		var area := _pickup_areas[i]
		area.visible = not taken
		# monitoring 不能在 body_entered 的回呼裡直接寫 ——
		# Godot 會擋下「訊號派送中修改監聽狀態」。走 deferred。
		area.set_deferred(&"monitoring", not taken)


# ──────────────────────────────────────────────────────────────
# 重置與出界
# ──────────────────────────────────────────────────────────────

## 兩人一起回出生點,空間回正常,鏡頭直接 snap(不平滑)。
##
## **空間非重置不可**:只送人回去而不重置空間的話,重生後會變成「人在起點,
## 但世界還停在異空間」,而封閉房間的右牆只存在於正常空間 —— 關卡的開場
## 直接壞掉,而且不會報錯。這類「不崩潰但靜靜地歪掉」的東西最貴。
##
## `clear_pickups` 是兩條路徑唯一的差別:
##   出界(false)—— 封閉房間是一次性的教學,**跑酷失手不該罰你重看一次**。
##                   實測一輪下來護目鏡被撿了 7 次、鑰匙 0 次,就是這個代價。
##   R 鍵(true) —— 除錯用,連拾取物一起清,真的回到開場。
##
## 上一輪把出界與 R 統一成同一個行為,理由是「N4 的前提消失了」——
## 那講的是鏡頭,而當時還沒有拾取物。這裡不是推翻那個決定,是把它延伸到
## 一個當時不存在的情況。
func _reset_all(reason: String, clear_pickups: bool) -> void:
	for i: int in _players.size():
		if i < spawn_points.size():
			_players[i].teleport_to(spawn_points[i])

	if clear_pickups:
		_goggles_holder = -1
		_key_taken = false
	_active_space = SPACE_NORMAL
	_apply_space()
	_refresh_pickups()

	_camera.snap_to_target()
	print("[Level] 重置(%s%s)" % [reason, "" if clear_pickups else ",拾取物保留"])


## 出界防護:任何一人掉到 bounds 下緣以外,「兩個人」一起回出生點。
##
## N4 當初的處置是「回最近的安全落腳點」,理由是鏡頭由
## trail_x = min(p1.x, p2.x) 驅動 —— 只把一個人送回起點會讓 trail_x 暴跌、
## 鏡頭一路滑回開頭,還在前面的另一個玩家被推出畫面,違反「永不把落後者
## 推出畫面」。
##
## 改成兩人一起回之後,那個衝突不存在了:沒有人留在遠處,鏡頭 snap 一次
## 就位,鏡頭規格仍然成立。這是 owner 拍板的設計決定 —— 一個人失誤兩個人
## 一起回去,是刻意的合作壓力,不是副作用。
##
## 連帶:`last_grounded_position` 不再兼任重生點,只服務鏡頭的垂直參考點。
func _guard_out_of_bounds() -> void:
	var floor_y := bounds.end.y
	for i: int in _players.size():
		var p: Player = _players[i]
		if p.global_position.y > floor_y:
			# 記下是「誰」在「哪裡」掉下去的。兩個人一起重置的規則之下,
			# 光看「出界了」分不出是自己失手還是被隊友的切換丟下 ——
			# 而那兩件事要改的東西完全不同。
			_reset_all("出界:P%d 掉在 x=%.0f" % [i + 1, p.global_position.x], false)
			return


# ──────────────────────────────────────────────────────────────
# 空間的小工具
# ──────────────────────────────────────────────────────────────

func _space_layers(space: StringName) -> int:
	match space:
		SPACE_NORMAL:
			return LAYER_NORMAL
		SPACE_ALT:
			return LAYER_ALT
	return LAYER_NORMAL | LAYER_ALT


func _space_color(space: StringName) -> Color:
	match space:
		SPACE_NORMAL:
			return COLOR_NORMAL
		SPACE_ALT:
			return COLOR_ALT
	return COLOR_BOTH


func _pickup_color(kind: StringName) -> Color:
	return COLOR_GOGGLES if kind == &"goggles" else COLOR_KEY


## 兩個 space 標記是否有交集。both 跟誰都有交集。
func _spaces_overlap(a: StringName, b: StringName) -> bool:
	return a == SPACE_BOTH or b == SPACE_BOTH or a == b
