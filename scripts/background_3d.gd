extends Node3D
## 3D 背景層。唯一的輸入是 SharedCamera 的 camera_moved 訊號 ——
## 這一層不知道玩家、不知道關卡、不參與任何玩法邏輯,只是被鏡頭位置驅動的
## 一組會視差的方塊。兩層的解耦就是靠這個單向的訊號。
##
## WebGL2 限制:只用純色 clear + 單一 DirectionalLight3D。
## 不用 glow / SSAO / SDFGI / 體積霧 —— Compatibility 後端沒有這些。

## 2D 邏輯單位換算成 3D 世界單位。對邏輯單位定義(1920x1080 尺度),
## 所以不隨 render_divisor 改變。100 邏輯單位 ↔ 1 個 3D 單位。
@export var world_units_per_pixel: float = 0.01
## 背景相對鏡頭的移動比例。0 = 完全不動,1 = 跟鏡頭同速。
@export var parallax_factor: float = 0.15
@export var camera_fov: float = 60.0
## 三層方塊的深度。透視投影本身就會讓遠的那層移動較少,
## 所以深度分層的視差是免費的,不需要為每層各設一個係數。
@export var layer_depths: Array[float] = [-60.0, -30.0, -15.0]

@onready var _camera: Camera3D = $Camera3D
@onready var _layers: Array[Node3D] = [$LayerFar, $LayerMid, $LayerNear]

var _base_camera_position: Vector3


func _ready() -> void:
	_camera.fov = camera_fov
	_base_camera_position = _camera.position
	for i: int in _layers.size():
		if i < layer_depths.size():
			_layers[i].position.z = layer_depths[i]


## 由 Main._ready() 接到 SharedCamera.camera_moved。
func on_camera_moved(cam2d_pos: Vector2) -> void:
	var k := world_units_per_pixel * parallax_factor
	# y 一定要取負號:2D 的 y 向下為正,3D 的 y 向上為正。
	# 漏掉這個負號畫面不會壞,只會讓背景往反方向飄 —— 很容易被當成
	# 「視差係數調錯了」而去改 parallax_factor,那是查錯地方。
	_camera.position = Vector3(
		_base_camera_position.x + cam2d_pos.x * k,
		_base_camera_position.y - cam2d_pos.y * k,
		_base_camera_position.z)
