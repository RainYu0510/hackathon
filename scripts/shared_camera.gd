extends Camera2D
class_name SharedCamera
## 兩人共用的單一鏡頭,落後者優先。
##
## 四條規則:
##   1. 只有一個共用鏡頭
##   2. 永不把落後者推出畫面
##   3. 落後者到達畫面中央後,鏡頭才前進
##   4. 垂直跟隨,並 clamp 在關卡邊界內
##
## 行為後果(不是 bug):固定 zoom 下,兩人距離超過 half_w 時領先者會跑出
## 畫面。只要有人得離開畫面,規格說了不能是落後者 —— 這是規則 2+3 的必然
## 結果。動態 zoom / 自動縮放框住兩人這輪不做。

signal camera_moved(pos: Vector2)

## 前進方向。+1 = 往 +x 前進,落後者是 x 較小者;-1 則相反。
@export var forward_sign: float = 1.0
@export var deadzone_x: float = 24.0
@export var deadzone_y: float = 48.0
## 指數平滑速率。實際係數是 1 - exp(-speed * delta),所以與 frame rate 無關。
## Camera2D 內建的 position_smoothing 已在 .tscn 顯式關掉,避免雙重平滑。
@export var smoothing_speed: float = 8.0
## 把鏡頭釘在渲染像素網格上。
## snap_2d_transforms_to_pixel 管的是物件相對於畫布;鏡頭自己次像素移動時
## 整個場景會相對像素網格漂移,那才是像素爬行的主因。兩者正交,可同時開。
## 代價是鏡頭移動變階梯狀,divisor=4 時一階 = 1 個渲染像素。
@export var snap_camera_to_pixel: bool = true

var _bounds: Rect2
var _p1: Node2D
var _p2: Node2D
var _ready_to_run: bool = false


func _ready() -> void:
	# 架構約束 2:_ready() 是子先於父,此時 Main 還沒設 SubViewport 尺寸與
	# zoom。在這裡跑任何鏡頭數學都會用到 512x512 / zoom 0.25,算出
	# half_w = 1024 而不是 960 —— 而且不會崩潰,只會「邊界怪怪的」。
	# 關掉 process,讓「未初始化就跑」變成不可能,而不是靠 _ready() 順序運氣。
	set_physics_process(false)


## 由 Level.activate() 呼叫,而 Level.activate() 由 Main._ready() 呼叫。
## 到這個時間點 SubViewport 尺寸與 zoom 都已經是對的。
func setup(p_bounds: Rect2, p_initial_pos: Vector2, p1: Node2D, p2: Node2D) -> void:
	_bounds = p_bounds
	_p1 = p1
	_p2 = p2
	position = p_initial_pos
	_ready_to_run = true

	var hw := _half_extents()
	print("[SharedCamera] setup  viewport=%s zoom=%s  half_w=%.1f half_h=%.1f" % [
		get_viewport_rect().size, zoom, hw.x, hw.y])
	if not is_equal_approx(hw.x, 960.0):
		push_warning("[SharedCamera] half_w=%.1f,預期 960 —— 初始化順序可能出問題" % hw.x)

	snap_to_target()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	var target := _compute_target()

	# 死區:目標與現況差距太小就不動,避免站著不動時鏡頭微幅抖動。
	if absf(target.x - position.x) < deadzone_x:
		target.x = position.x
	if absf(target.y - position.y) < deadzone_y:
		target.y = position.y

	# frame-rate 無關的指數平滑。
	var t := 1.0 - exp(-smoothing_speed * delta)
	_commit(position.lerp(target, t))


## 直接跳到目標位置,跳過死區與平滑。setup() 與 Level._reset_all() 用。
func snap_to_target() -> void:
	if not _ready_to_run:
		return
	_commit(_compute_target())


# ──────────────────────────────────────────────────────────────
# 內部
# ──────────────────────────────────────────────────────────────

## 半可視範圍。每幀重算,不快取 —— 兩次除法的成本可忽略,換到的是
## 「改 render_divisor 時不必記得去哪裡重算」。
## zoom = 1/divisor 且 viewport = 1920/divisor,所以這個值恆為 (960, 540)。
func _half_extents() -> Vector2:
	var vp := get_viewport_rect().size
	return Vector2(vp.x * 0.5 / zoom.x, vp.y * 0.5 / zoom.y)


func _compute_target() -> Vector2:
	# 水平:只由落後者驅動。領先者往前跑不改變 trail_x,鏡頭就不動 ——
	# 這同時滿足規則 2 與規則 3。
	var trail_x: float
	if forward_sign >= 0.0:
		trail_x = minf(_p1.global_position.x, _p2.global_position.x)
	else:
		trail_x = maxf(_p1.global_position.x, _p2.global_position.x)

	# 垂直:用最後落地的 y,跳躍時鏡頭才不會跟著上下抖。
	var target_y := (_reference_y(_p1) + _reference_y(_p2)) * 0.5
	return Vector2(trail_x, target_y)


func _reference_y(p: Node2D) -> float:
	var player := p as Player
	if player != null and not player.is_on_floor():
		return player.last_grounded_position.y
	return p.global_position.y


## clamp → 像素對齊 → 寫入 → 發訊號。順序不可調換:
## clamp 一定要在平滑之後(否則平滑會把鏡頭帶出邊界),
## 像素對齊一定要在 clamp 之後(否則對齊會把鏡頭推出邊界一個像素)。
func _commit(pos: Vector2) -> void:
	var half := _half_extents()

	# 關卡比畫面窄時,clamp 的上下限會交叉。這時置中,不要讓 clamp 亂跳。
	if _bounds.size.x >= half.x * 2.0:
		pos.x = clampf(pos.x, _bounds.position.x + half.x, _bounds.end.x - half.x)
	else:
		pos.x = _bounds.get_center().x
	if _bounds.size.y >= half.y * 2.0:
		pos.y = clampf(pos.y, _bounds.position.y + half.y, _bounds.end.y - half.y)
	else:
		pos.y = _bounds.get_center().y

	if snap_camera_to_pixel:
		# 一個渲染像素 = divisor 個邏輯單位。divisor 從 zoom 反推,
		# 這樣就不必在兩個地方各放一份同樣的旋鈕。
		var logical_per_render_pixel := 1.0 / zoom.x
		if logical_per_render_pixel > 0.0:
			pos = (pos / logical_per_render_pixel).round() * logical_per_render_pixel

	position = pos
	camera_moved.emit(pos)
