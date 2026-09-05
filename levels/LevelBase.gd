class_name LevelBase
extends Node2D

var hud: Label
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
	if Input.is_action_just_pressed("debug_normal"): DimensionManager.set_dimension(DimensionManager.Dimension.NORMAL)
	if Input.is_action_just_pressed("debug_alternate"): DimensionManager.set_dimension(DimensionManager.Dimension.ALTERNATE)
	if Input.is_action_just_pressed("debug_info"): hud.visible = not hud.visible
	if hud:
		var players := get_tree().get_nodes_in_group("player")
		var owner := "None"
		var hp := []
		for p in players:
			if p.has_goggle: owner = "Player %d" % (p.player_index + 1)
			hp.append("P%d HP: %d" % [p.player_index + 1, p.health.health])
		hud.text = "Dimension: %s\nGoggle Owner: %s\nKey: %s\n%s\nF1 HUD  F2 Normal  F3 Alternate  R Reset" % [DimensionManager.label(), owner, "Yes" if GameManager.has_key else "No", "   ".join(hp)]

func _build_common() -> void:
	var canvas := CanvasLayer.new(); canvas.name = "HUD"; add_child(canvas)
	hud = Label.new(); hud.position = Vector2(18,18); hud.add_theme_font_size_override("font_size", 18); hud.modulate = Color("dffcff"); canvas.add_child(hud)
	var controls := Label.new(); controls.position = Vector2(18,620); controls.text = "P1: A/D/W · F Attack · G Interact/Dimension     P2: Arrows · K Attack · L Interact"; controls.add_theme_font_size_override("font_size",16); canvas.add_child(controls)
	var camera := Camera2D.new(); camera.name = "SharedCamera2D"; camera.position = Vector2(520,400); camera.position_smoothing_enabled = true; camera.position_smoothing_speed = 5; camera.set_script(load("res://systems/SharedCamera.gd")); add_child(camera)
	var death := Area2D.new(); death.name = "DeathZone"; death.collision_layer = 0; death.collision_mask = 2; death.set_script(load("res://interactables/DeathZone.gd")); add_child(death)
	var shape := CollisionShape2D.new(); var rect := RectangleShape2D.new(); rect.size = Vector2(5000,200); shape.shape = rect; shape.position = Vector2(2000,900); death.add_child(shape)

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
	var door := Sprite2D.new(); door.texture = load("res://assets/interactables/locked_door.png"); door.position = Vector2(0,-52); door.scale = Vector2(140.0 / door.texture.get_width(), 140.0 / door.texture.get_height()); door.z_index = 3; area.add_child(door)
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

func _on_level_complete() -> void:
	var message := Label.new(); message.text="LEVEL COMPLETE"; message.position=Vector2(465,250); message.add_theme_font_size_override("font_size",46); $HUD.add_child(message)

## ─── 關卡串接接口 ───────────────────────────────────────────
## 下一關的場景路徑。子類別在 build_level() 開頭設定。
## 留空字串 = 目前沒有下一關,通關只顯示 LEVEL COMPLETE(R 可重玩)。
var next_scene_path := ""
var _transitioning := false   # one-shot,擋掉兩名玩家各觸發一次換場
var _exit_armed := false

func go_to_next_level() -> void:
	if _transitioning:
		return
	_transitioning = true
	GameManager.complete_level()
	if next_scene_path.is_empty():
		return                 # 最後一關:只顯示 LEVEL COMPLETE
	get_tree().call_deferred("change_scene_to_file", next_scene_path)

## 建立出口觸發器。require_key 為 true 時必須先拿到鑰匙。
func exit_trigger(pos: Vector2, size: Vector2, require_key := false) -> Area2D:
	var area := Area2D.new(); area.position = pos; area.collision_layer = 0; area.collision_mask = 2
	var cs := CollisionShape2D.new(); var rect := RectangleShape2D.new(); rect.size = size; cs.shape = rect; area.add_child(cs)
	area.body_exited.connect(_on_exit_body_exited)
	area.body_entered.connect(_on_exit_body_entered.bind(require_key))
	add_child(area)
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
	if body.is_in_group("player"):
		_exit_armed = true

func _on_exit_body_entered(body: Node, require_key: bool) -> void:
	if not _exit_armed or not body.is_in_group("player"):
		return
	if require_key and not GameManager.has_key:
		return
	go_to_next_level()
