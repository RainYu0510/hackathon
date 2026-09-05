extends Node3D
class_name Background3D
## 3D 背景層。輸入只有兩條訊號:SharedCamera 的 camera_moved、Level 的
## space_changed —— 這一層不知道玩家、不知道關卡狀態、不參與任何玩法邏輯,
## 只是被鏡頭位置與空間名字驅動的一組會視差的方塊。兩層的解耦就是靠這兩條
## 單向訊號。
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

## 異空間的色組。**正常空間那組不寫在這裡** —— 開場時直接從場景讀下來,
## 這樣 background_3d.tscn 仍然是「正常空間長什麼樣」的唯一來源,
## 不會變成同一份設定的第二個欄位。
@export var alt_layer_colors: Array[Color] = [
	Color(0.26, 0.15, 0.32),   # LayerFar
	Color(0.34, 0.19, 0.40),   # LayerMid
	Color(0.18, 0.10, 0.24),   # LayerNear
]
@export var alt_background_color: Color = Color(0.11, 0.05, 0.16)
@export var alt_ambient_color: Color = Color(0.42, 0.26, 0.52)
@export var alt_light_color: Color = Color(0.92, 0.72, 1.00)

@onready var _camera: Camera3D = $Camera3D
@onready var _light: DirectionalLight3D = $DirectionalLight3D
@onready var _world_env: WorldEnvironment = $WorldEnvironment
@onready var _layers: Array[Node3D] = [$LayerFar, $LayerMid, $LayerNear]

var _base_camera_position: Vector3

## 每層共用一份 StandardMaterial3D sub-resource(見 .tscn 的
## surface_material_override/0),所以改一份就換掉那層全部的方塊,
## 不必碰 24 個 MeshInstance3D。
var _layer_materials: Array[StandardMaterial3D] = []
var _normal_layer_colors: Array[Color] = []
var _normal_background_color: Color
var _normal_ambient_color: Color
var _normal_light_color: Color


func _ready() -> void:
	_camera.fov = camera_fov
	_base_camera_position = _camera.position
	for i: int in _layers.size():
		if i < layer_depths.size():
			_layers[i].position.z = layer_depths[i]

	_capture_normal_palette()


## 把場景裡現有的顏色記下來當「正常空間」那一組。
## 這樣切回正常空間時是還原場景的值,不是還原一份寫在程式碼裡的拷貝。
func _capture_normal_palette() -> void:
	_layer_materials.clear()
	_normal_layer_colors.clear()
	for layer: Node3D in _layers:
		var mat := _first_surface_material(layer)
		_layer_materials.append(mat)
		_normal_layer_colors.append(mat.albedo_color if mat != null else Color.WHITE)

	var env := _world_env.environment
	if env != null:
		_normal_background_color = env.background_color
		_normal_ambient_color = env.ambient_light_color
	_normal_light_color = _light.light_color


func _first_surface_material(layer: Node3D) -> StandardMaterial3D:
	for child: Node in layer.get_children():
		var mesh := child as MeshInstance3D
		if mesh != null:
			return mesh.get_surface_override_material(0) as StandardMaterial3D
	return null


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


## 由 Main._ready() 接到 Level.space_changed。第一次會在 Level.activate()
## 裡發出來,所以背景開場就是對的顏色,不需要在這裡自己初始化一次。
##
## 收 StringName 而不是關卡腳本的 enum:這一層不依賴 Level 的型別。
##
## **只換顏色**,不做動畫、粒子、天空盒或動態光照
## (plan-v5〈這輪不做〉#15;一次性的靜態色組切換不在那條的本意裡)。
func on_space_changed(space: StringName) -> void:
	var alt := space == &"alt"

	for i: int in _layer_materials.size():
		var mat := _layer_materials[i]
		if mat == null:
			continue
		if alt and i < alt_layer_colors.size():
			mat.albedo_color = alt_layer_colors[i]
		else:
			mat.albedo_color = _normal_layer_colors[i]

	var env := _world_env.environment
	if env != null:
		env.background_color = alt_background_color if alt else _normal_background_color
		env.ambient_light_color = alt_ambient_color if alt else _normal_ambient_color

	_light.light_color = alt_light_color if alt else _normal_light_color
