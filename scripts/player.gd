extends CharacterBody2D
class_name Player
## 玩家控制器。一份腳本兩個實例,靠 input_prefix 區分。
##
## 架構約束 1(見 AGENTS.md):輸入一律輪詢 Input singleton。
## 這個節點在 GameViewport 底下,而 GameViewport 是裸掛的 SubViewport ——
## _input() / _unhandled_input() 收不到任何事件。不要改用輸入回呼。

## 物理常數,全部是邏輯單位(1920x1080 尺度),不隨 render_divisor 改變。
##   跳躍高度 = jump_velocity^2 / (2 * gravity) = 1250^2 / 5200 ≈ 300.5
##   滯空時間 = 2 * |jump_velocity| / gravity   = 2500 / 2600  ≈ 0.962 s
## 改這些值就要重算 level.gd 的 MAX_GAP,那裡有完整推導。
@export var speed: float = 420.0
@export var jump_velocity: float = -1250.0
@export var gravity: float = 2600.0
## 離開平台邊緣後仍可起跳的寬限時間。這輪唯一做的「手感」項目 ——
## jump buffer、可變跳躍高度、加減速曲線都不做。
@export var coyote_time: float = 0.1

## 由 Level 在 add_child() 之前設定(架構約束 2:父推子)。
## p1 = WASD;p2 = IJKL(外加數字鍵盤 4/6/8)。
## p2 不用方向鍵:實測這台鍵盤 W + ↑ + → 三顆同時會被矩陣封鎖掉,
## 詳見 dev-log 的 rollover 實測表。
@export var input_prefix: StringName = &"p1"
## 貼圖染色。這是 modulate 的相乘染色,不是「身體的顏色」——
## 白色 = 不染,保留美術原色。黑貓身上會被染到的其實只有亮部
## (連帽衫、球鞋、墨鏡、眼睛),黑色的身體怎麼乘都還是黑的。
@export var tint: Color = Color.WHITE

## 最後一次踩在地板上的位置。SharedCamera 拿它的 y 當垂直參考點,
## 讓跳躍時鏡頭不跟著上下抖。
## 初始值 = 出生點,不是 Vector2.ZERO —— 否則第一幀還沒落地時鏡頭
## 的垂直參考點是 0,鏡頭會被拉到關卡上緣。
##
## 這個欄位原本還兼任出界重生點(N4)。重生改成「兩人一起回出生點」之後
## 那個用途沒了,欄位保留是因為鏡頭仍然需要它。
var last_grounded_position: Vector2 = Vector2.ZERO

var _action_left: StringName
var _action_right: StringName
var _action_jump: StringName
var _coyote_timer: float = 0.0

## make_spritesheet.py 的 --margin。寫死在這裡是為了讓下面的斷言算得出
## 「角色內容」有多高 —— cell 上下各留這麼多列的空白。
const SPRITE_MARGIN_PX := 1

## 貼圖對位靠的是整數關係,不是眼睛喬出來的:
##   cell 40x46 art px,角色內容佔第 1..44 列(上下各留 1px)→ 垂直置中
##   render_divisor = 2,所以 1 art px = 2 世界單位
##   scale 2 → 內容 44 * 2 = 88 世界單位高,與碰撞箱的 88 完全吻合
## 所以節點放在原點、centered 用預設的 true 就對齊了,不需要 offset。
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_action_left = StringName("%s_move_left" % input_prefix)
	_action_right = StringName("%s_move_right" % input_prefix)
	_action_jump = StringName("%s_jump" % input_prefix)
	_sprite.modulate = tint
	last_grounded_position = global_position
	_assert_sprite_matches_hitbox()


func _physics_process(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
		last_grounded_position = global_position
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
		velocity.y += gravity * delta

	velocity.x = Input.get_axis(_action_left, _action_right) * speed

	if Input.is_action_just_pressed(_action_jump) and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_coyote_timer = 0.0

	move_and_slide()
	_update_animation()


## 貼圖高度、sprite scale、main.gd 的 render_divisor 這三個數字是綁在一起的:
##   角色 art 高度 = 88 / render_divisor,而 scale 必須等於 render_divisor。
## 只改其中一個的話畫面不會報錯,只會靜默地把角色畫成錯的大小 —— 那種 bug
## 很難從畫面反推,所以在這裡擋一次。
func _assert_sprite_matches_hitbox() -> void:
	var frames: SpriteFrames = _sprite.sprite_frames
	if frames == null or not frames.has_animation(&"idle"):
		push_error("[Player] AnimatedSprite2D 沒有 SpriteFrames 或缺 idle 動畫")
		return
	var cell_h: float = float(frames.get_frame_texture(&"idle", 0).get_height())
	var content_h: float = (cell_h - 2.0 * SPRITE_MARGIN_PX) * _sprite.scale.y
	var box_h: float = ((_collision.shape as RectangleShape2D).size.y)
	if not is_equal_approx(content_h, box_h):
		push_error(
			"[Player] 貼圖與碰撞箱不等高:內容 %.1f vs 碰撞箱 %.1f。"
			% [content_h, box_h]
			+ "檢查 make_spritesheet.py 的 --height、player.tscn 的 scale、"
			+ "main.gd 的 render_divisor 是否一致。"
		)


## 只有 run 是真動畫,idle 與 jump 各自凍在一格上 —— 來源素材只有跑步循環
## 這 8 格。站著不動或滯空時繼續播跑步會很怪,凍住反而讀得出來。
##
## 判斷順序不能顛倒:滯空優先於水平速度,否則跳躍中還按著左右鍵會播成跑步。
func _update_animation() -> void:
	# 速度為 0 時不改朝向 —— 否則一放開按鍵角色就會轉回右邊。
	if not is_zero_approx(velocity.x):
		_sprite.flip_h = velocity.x < 0.0   # 素材裡的貓面朝右

	var next: StringName = &"idle"
	if not is_on_floor():
		next = &"jump"
	elif not is_zero_approx(velocity.x):
		next = &"run"

	# play() 會從頭播。每幀無條件呼叫的話跑步循環會永遠停在第一格。
	if _sprite.animation != next:
		_sprite.play(next)


## 回到指定位置並清空動量。R 鍵重置與出界防護都走這裡。
func teleport_to(target: Vector2) -> void:
	global_position = target
	velocity = Vector2.ZERO
	_coyote_timer = 0.0
	last_grounded_position = target


## 由 Level 在 _ready() 之後呼叫。不能只寫 tint ——
## _ready() 早就跑完了,那個 export 只在 _ready() 當下被讀一次。
func set_tint(c: Color) -> void:
	tint = c
	_sprite.modulate = c
