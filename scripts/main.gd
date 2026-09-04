extends Node2D
## 合成層的根節點,也是**唯一的初始化排序點**。
##
## 架構約束 2(見 AGENTS.md):Godot 的 _ready() 是子先於父,實際順序是
## SharedCamera -> Level -> Main。所有跨節點的初始化都必須在這裡發生,
## 因為 Main 是最後 _ready() 的節點,只有它看得到全部子節點的最終狀態。
##
## 這個檔案不含任何玩法邏輯,只做接線。

## 世界座標空間。關卡座標與物理常數全部以這個尺度撰寫,永不改變。
const LOGICAL_SIZE := Vector2i(1920, 1080)

## 唯一的畫質旋鈕。改這個值不需要動關卡資料或物理常數:
##   1 -> 1920x1080   2 -> 960x540   3 -> 640x360   4 -> 480x270   6 -> 320x180
## 兩個 SubViewport 的像素數會跟著變,但相機 zoom 同步補償,
## 所以可視世界永遠是 1920x1080,half_w 恆為 960。
##
## **但它跟玩家貼圖是綁在一起的。** 角色在螢幕上的高度 = 88 / render_divisor,
## 而貼圖必須用同樣的比例產出才會是像素對齊的。改這個值就要一起改:
##   1. tools/make_spritesheet.py 的 --height,值 = 88 / render_divisor
##   2. scenes/player.tscn 裡 AnimatedSprite2D 的 scale,值 = render_divisor
## 三者不一致時 Player._ready() 會 push_error 擋下來,不會靜默畫錯。
##
## 可用值只有 {1, 2, 4, 8}:必須同時整除 88(角色高)與 1920/1080(畫面),
## 否則貼圖對不齊像素格。3 和 6 雖然整除畫面,但 88/3、88/6 不是整數。
##
## 從 4 改成 2 的理由:4 時角色只有 22px 高,這隻貓的細節量(墨鏡、球鞋、
## 連帽衫)在那個尺寸下糊成一團,辨識不出來。
@export_range(1, 8, 1) var render_divisor: int = 2

@onready var _bg_viewport: SubViewport = $BgViewport
@onready var _game_viewport: SubViewport = $GameViewport
@onready var _background_view: TextureRect = $Compositor/BackgroundView
@onready var _gameplay_view: TextureRect = $Compositor/GameplayView
@onready var _background_3d: Node3D = $BgViewport/Background3D
@onready var _level: Node2D = $GameViewport/Level
@onready var _camera: SharedCamera = $GameViewport/Level/SharedCamera


## 順序不可調換。每一步都是下一步的前提:
##   1. 尺寸  —— 決定 half_w 的分子
##   2. zoom  —— 決定 half_w 的分母
##   3. 貼圖  —— 必須在尺寸定案後才拿 ViewportTexture
##   4. 訊號  —— 背景層要能收到第一次 camera_moved
##   5. 放行  —— 到這裡鏡頭算什麼都是對的
func _ready() -> void:
	var d := maxi(render_divisor, 1)
	if LOGICAL_SIZE.x % d != 0 or LOGICAL_SIZE.y % d != 0:
		push_warning("[Main] render_divisor=%d 不能整除 %s,渲染尺寸會有捨入誤差" % [d, LOGICAL_SIZE])

	var render_size := LOGICAL_SIZE / d
	_bg_viewport.size = render_size
	_game_viewport.size = render_size

	_camera.zoom = Vector2.ONE / float(d)

	_background_view.texture = _bg_viewport.get_texture()
	_gameplay_view.texture = _game_viewport.get_texture()

	_camera.camera_moved.connect(_background_3d.on_camera_moved)

	print("[Main] divisor=%d render=%s zoom=%s 可視世界=%s" % [
		d, render_size, _camera.zoom, Vector2(render_size) / _camera.zoom])

	_level.activate()
