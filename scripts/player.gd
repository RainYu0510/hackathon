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
@export var body_color: Color = Color(0.90, 0.38, 0.32)

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

@onready var _body_rect: ColorRect = $ColorRect


func _ready() -> void:
	_action_left = StringName("%s_move_left" % input_prefix)
	_action_right = StringName("%s_move_right" % input_prefix)
	_action_jump = StringName("%s_jump" % input_prefix)
	_body_rect.color = body_color
	last_grounded_position = global_position


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


## 回到指定位置並清空動量。R 鍵重置與出界防護都走這裡。
func teleport_to(target: Vector2) -> void:
	global_position = target
	velocity = Vector2.ZERO
	_coyote_timer = 0.0
	last_grounded_position = target


## 由 Level 在 _ready() 之後呼叫。不能只寫 body_color ——
## _ready() 早就跑完了,那個 export 只在 _ready() 當下被讀一次。
func set_body_color(c: Color) -> void:
	body_color = c
	_body_rect.color = c
