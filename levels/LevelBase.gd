class_name LevelBase
extends Node2D

## 主選單場景。關卡裡按 Esc 叫出暫停面板,從那裡的「回主選單」回到這裡。
## PauseMenu 也讀這個常數,路徑只有這一份。
const MAIN_MENU_PATH := "res://ui/MainMenu.tscn"

var hud: Label
var pause_menu: CanvasLayer
var collapse_platforms: Array[Node] = []

func _ready() -> void:
	GameManager.reset_level_state()
	_build_common()
	build_level()
	GameManager.key_collected.connect(_on_key_collected)
	GameManager.level_completed.connect(_on_level_complete)

func build_level() -> void:
	pass

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("reset_room"): get_tree().reload_current_scene()
	# 暫停中這個 _process 不會跑(節點是預設的 inherit),所以 Esc 只會「開啟」;
	# 收起面板由 PauseMenu 自己輪詢,兩邊不會互搶。
	if pause_menu and Input.is_action_just_pressed("ui_cancel"): pause_menu.open()
	if Input.is_action_just_pressed("debug_normal"): DimensionManager.set_dimension(DimensionManager.Dimension.NORMAL)
	if Input.is_action_just_pressed("debug_alternate"): DimensionManager.set_dimension(DimensionManager.Dimension.ALTERNATE)
	if hud and Input.is_action_just_pressed("debug_info"): hud.visible = not hud.visible
	# 除錯 HUD 藏起來時就不必每幀走一次 player group、也不必解參照 health。
	if hud and hud.visible:
		var players := get_tree().get_nodes_in_group("player")
		var owner := "None"
		var hp := []
		for p in players:
			if p.has_goggle: owner = "Player %d" % (p.player_index + 1)
			hp.append("P%d HP: %d" % [p.player_index + 1, p.health.health])
		hud.text = "Dimension: %s\nGoggle Owner: %s\nKey: %s\n%s\nF1 HUD  F2 Normal  F3 Alternate  R Reset" % [DimensionManager.label(), owner, "Yes" if GameManager.has_key else "No", "   ".join(hp)]

func _build_common() -> void:
	var canvas := CanvasLayer.new(); canvas.name = "HUD"; add_child(canvas)
	# 除錯 HUD 預設隱藏 —— 空間/護目鏡/鑰匙/雙方 HP 是開發用數值,不是給玩家看的。
	# F1 仍然可以叫出來。
	hud = Label.new(); hud.position = Vector2(18,18); hud.add_theme_font_size_override("font_size", 18); hud.modulate = Color("dffcff"); hud.visible = false; canvas.add_child(hud)
	# 操作提示列 —— 這是給玩家看的,永遠顯示。R / Esc 也寫在這裡:原本只寫在除錯 HUD
	# 的文字裡,HUD 一藏就跟著不見。F1/F2/F3 是開發鍵,留在除錯 HUD 裡就好。
	var controls := Label.new(); controls.position = Vector2(18,620); controls.text = "P1: A/D/W · F Attack · G Interact/Dimension     P2: Arrows · K Attack · L Interact     R Restart · Esc Pause"; controls.add_theme_font_size_override("font_size",16); canvas.add_child(controls)
	var camera := Camera2D.new(); camera.name = "SharedCamera2D"; camera.position = Vector2(520,400); camera.position_smoothing_enabled = true; camera.position_smoothing_speed = 5; camera.set_script(load("res://systems/SharedCamera.gd")); add_child(camera)
	var death := Area2D.new(); death.name = "DeathZone"; death.collision_layer = 0; death.collision_mask = 2; death.set_script(load("res://interactables/DeathZone.gd")); add_child(death)
	var shape := CollisionShape2D.new(); var rect := RectangleShape2D.new(); rect.size = Vector2(5000,200); shape.shape = rect; shape.position = Vector2(2000,900); death.add_child(shape)
	# 暫停面板:繼續 / 回主選單 / 離開遊戲。父推子,由關卡掛上去。
	pause_menu = preload("res://ui/PauseMenu.tscn").instantiate(); add_child(pause_menu)

func spawn_players(p1: Vector2, p2: Vector2) -> void:
	var cat := preload("res://actors/players/NoxCat/NoxCat.tscn").instantiate(); cat.position = p1; add_child(cat)
	var dog := preload("res://actors/players/CyberDog/CyberDog.tscn").instantiate(); dog.position = p2; add_child(dog)

func platform(parent: Node, pos: Vector2, size: Vector2, color: Color) -> StaticBody2D:
	var body := StaticBody2D.new(); body.position = pos; body.collision_layer = 1; body.collision_mask = 0; parent.add_child(body)
	var sprite := Sprite2D.new()
	var alternate := parent.name == "AlternateWorld"
	var texture_path := "res://assets/dimensions/crimson/platforms/platform_crimson_03.png" if alternate else "res://assets/dimensions/alternate/platforms/platform_03.png"
	if size.y >= 60.0:
		texture_path = "res://assets/dimensions/crimson/platforms/platform_crimson_02.png" if alternate else "res://assets/dimensions/alternate/platforms/platform_02.png"
	var platform_texture: Texture2D = load(texture_path)
	if platform_texture:
		sprite.texture = platform_texture
		sprite.scale = Vector2(size.x / platform_texture.get_width(), size.y / platform_texture.get_height())
		sprite.z_index = 2
		sprite.modulate = Color(1.18, 1.18, 1.18, 1.0)
		body.add_child(sprite)
	else:
		var poly := Polygon2D.new(); poly.polygon = PackedVector2Array([-size/2,Vector2(size.x/2,-size.y/2),size/2,Vector2(-size.x/2,size.y/2)]); poly.color = color; body.add_child(poly)
	var collision := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = size; collision.shape = shape; body.add_child(collision)
	return body

func dimension_background(parent: Node2D, alternate := false) -> void:
	var path := "res://assets/dimensions/crimson/backgrounds/alternate_dimension_crimson.png" if alternate else "res://assets/dimensions/alternate/backgrounds/alternate_dimension.png"
	var texture: Texture2D = load(path)
	if not texture:
		return
	var tile_width := 1400.0
	for i in range(4):
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.position = Vector2(700.0 + i * tile_width, 360.0)
		sprite.scale = Vector2(tile_width / texture.get_width(), 720.0 / texture.get_height())
		sprite.modulate = Color(0.52, 0.52, 0.58, 0.82)
		sprite.z_index = -20
		parent.add_child(sprite)

func checkpoint(pos: Vector2) -> void:
	var area := Area2D.new(); area.position = pos; area.collision_layer = 0; area.collision_mask = 2; area.set_script(load("res://interactables/Checkpoint.gd")); add_child(area)
	var poly := Polygon2D.new(); poly.name = "Polygon2D"; poly.visible = false; area.add_child(poly)
	var door := Sprite2D.new(); door.texture = load("res://assets/interactables/locked_door.png"); door.position = Vector2(0,-49); door.scale = Vector2(140.0 / door.texture.get_width(), 140.0 / door.texture.get_height()); door.z_index = -1; area.add_child(door)
	var cs := CollisionShape2D.new(); var shape:=RectangleShape2D.new(); shape.size=Vector2(45,100); cs.shape=shape; area.add_child(cs)

func pickup(pos: Vector2, key_pickup := false) -> void:
	var area:=Area2D.new(); area.position=pos; area.collision_layer=32; area.collision_mask=2; area.set_script(load("res://interactables/Key.gd" if key_pickup else "res://interactables/GogglePickup.gd")); add_child(area)
	if key_pickup:
		var key := Sprite2D.new(); key.texture = load("res://assets/interactables/key_icon.png"); var key_scale := 150.0 / key.texture.get_width(); key.scale = Vector2(key_scale,key_scale); key.z_index = 3; area.add_child(key)
	else:
		var goggle := Sprite2D.new(); goggle.texture = load("res://assets/interactables/goggle_icon.png"); goggle.scale = Vector2(62.0 / goggle.texture.get_width(), 62.0 / goggle.texture.get_height()); goggle.z_index = 3; area.add_child(goggle)
	var cs:=CollisionShape2D.new(); var shape:=RectangleShape2D.new(); shape.size=Vector2(65,65); cs.shape=shape; area.add_child(cs)

func _on_key_collected() -> void:
	for item in collapse_platforms:
		item.call("trigger")
	_update_exit_hint()

func _on_level_complete() -> void:
	var message := Label.new(); message.text="LEVEL COMPLETE"; message.position=Vector2(465,250); message.add_theme_font_size_override("font_size",46); $HUD.add_child(message)

## ─── 關卡串接接口 ───────────────────────────────────────────
## 下一關的場景路徑。子類別在 build_level() 開頭設定。
## 留空字串 = 目前沒有下一關,通關只顯示 LEVEL COMPLETE(R 可重玩)。
var next_scene_path := ""
var _transitioning := false   # one-shot,擋掉兩名玩家各觸發一次換場
var _exit_armed := false
var _exit_requires_key := false
var _exit_occupants: Array[Node] = []
var _exit_hint: Label

func go_to_next_level() -> void:
	if _transitioning:
		return
	_transitioning = true
	GameManager.complete_level()
	if next_scene_path.is_empty():
		return                 # 最後一關:只顯示 LEVEL COMPLETE
	get_tree().call_deferred("change_scene_to_file", next_scene_path)

## 建立出口觸發器。require_key 為 true 時必須先拿到鑰匙。
## 過關條件是「兩名玩家都在門框內」—— 單人衝到終點不能把隊友丟下自己過關。
## 三關共用這一套,不要再在各關自己寫一份門邏輯。
func exit_trigger(pos: Vector2, size: Vector2, require_key := false) -> Area2D:
	_exit_requires_key = require_key
	var area := Area2D.new(); area.position = pos; area.collision_layer = 0; area.collision_mask = 2
	var cs := CollisionShape2D.new(); var rect := RectangleShape2D.new(); rect.size = size; cs.shape = rect; area.add_child(cs)
	area.body_exited.connect(_on_exit_body_exited)
	area.body_entered.connect(_on_exit_body_entered.bind(require_key))
	add_child(area)
	_exit_hint = Label.new(); _exit_hint.text = "Both players must be at the door"; _exit_hint.position = Vector2(400,560); _exit_hint.add_theme_font_size_override("font_size",20); _exit_hint.visible = false; $HUD.add_child(_exit_hint)
	_arm_exit_when_clear(area)
	return area

## 出口若一開始就壓在玩家身上(第一關的門就是),等玩家離開才武裝;
## 否則(出口在關卡另一端)兩個物理幀後直接武裝。
## 這一步是必要的:Godot 對「生成時就重疊」的 body 會發 body_entered,
## 而瞬移進 Area2D 同樣會發 —— 兩者都可能被誤判成「走進門」。
func _arm_exit_when_clear(area: Area2D) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(area):
		return
	for body in area.get_overlapping_bodies():
		if body.is_in_group("player"):
			return             # 有人壓在出口上 → 交給 body_exited 武裝
	_exit_armed = true

func _on_exit_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_exit_occupants.erase(body)
	_exit_armed = true
	_update_exit_hint()

func _on_exit_body_entered(body: Node, require_key: bool) -> void:
	if not body.is_in_group("player"):
		return
	if not _exit_occupants.has(body):
		_exit_occupants.append(body)
	_try_exit(require_key)

## 兩名玩家都在門框內才換場。這裡不查 Area2D 的 get_overlapping_bodies() ——
## 那個在 body_entered 發出的同一幀內不保證已經更新,所以自己維護佔用名單。
func _try_exit(require_key: bool) -> void:
	_update_exit_hint()
	if _transitioning or not _exit_armed:
		return
	if require_key and not GameManager.has_key:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	for player in players:
		if not _exit_occupants.has(player):
			return
	go_to_next_level()

## 有人站在出口、但條件還沒滿足時給提示。沒有這個的話,玩家站在門口沒反應
## 會被當成「換場壞掉」回報。缺鑰匙與缺人是兩種不同的卡住,分開講清楚。
func _update_exit_hint() -> void:
	if not is_instance_valid(_exit_hint):
		return
	# 還沒武裝 = 玩家是「生在門框裡」而不是走進來的(第一關就是),
	# 這時候跳提示會變成一開場就有一行字掛在畫面上,看起來像壞掉。
	if not _exit_armed or _exit_occupants.is_empty():
		_exit_hint.visible = false
		return
	if _exit_requires_key and not GameManager.has_key:
		_exit_hint.text = "Find the key first"
		_exit_hint.visible = true
		return
	_exit_hint.text = "Both players must be at the door"
	_exit_hint.visible = _exit_occupants.size() < get_tree().get_nodes_in_group("player").size()
