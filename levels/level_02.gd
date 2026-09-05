extends LevelBase

const LEVEL_DATA_PATH := "res://data/level_02.json"
const NEXT_LEVEL_PATH := "res://levels/Level03.tscn"

var _exit_triggered := false

func build_level() -> void:
	var data := _load_level_data()
	if data.is_empty():
		return

	var spawn_data := data.get("spawn", {}) as Dictionary
	spawn_players(
		_array_to_vector2(spawn_data.get("player_1", [560, 680]) as Array),
		_array_to_vector2(spawn_data.get("player_2", [630, 680]) as Array)
	)
	for player_node: Node in get_tree().get_nodes_in_group("player"):
		var player := player_node as PlayerBase
		if player != null and player.player_index == 0:
			player.has_goggle = true

	var shared := Node2D.new()
	shared.name = "SharedObjects"
	add_child(shared)
	var normal := _create_dimension_world("NormalWorld", DimensionManager.Dimension.NORMAL)
	var alternate := _create_dimension_world("AlternateWorld", DimensionManager.Dimension.ALTERNATE)
	_build_vertical_background(normal, false)
	_build_vertical_background(alternate, true)

	var platform_data := data.get("platforms", []) as Array
	for raw_platform: Variant in platform_data:
		var entry := raw_platform as Dictionary
		var target: Node = shared
		match String(entry.get("world", "shared")):
			"normal":
				target = normal
			"alternate":
				target = alternate
		platform(
			target,
			_array_to_vector2(entry.get("position", [0, 0]) as Array),
			_array_to_vector2(entry.get("size", [220, 35]) as Array),
			Color("334463")
		)

	add_child(normal)
	add_child(alternate)
	_add_exit_door(_array_to_vector2(data.get("exit_door", [820, -100]) as Array))

func _load_level_data() -> Dictionary:
	var file := FileAccess.open(LEVEL_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Unable to open " + LEVEL_DATA_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Invalid level data in " + LEVEL_DATA_PATH)
		return {}
	return parsed as Dictionary

func _array_to_vector2(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))

func _create_dimension_world(world_name: String, dimension_value: DimensionManager.Dimension) -> Node2D:
	var world := Node2D.new()
	world.name = world_name
	world.set_script(load("res://systems/DimensionWorld.gd"))
	world.set("dimension", dimension_value)
	return world

func _build_vertical_background(parent: Node2D, alternate_world: bool) -> void:
	var path := "res://assets/dimensions/crimson/backgrounds/alternate_dimension_crimson.png" if alternate_world else "res://assets/dimensions/alternate/backgrounds/alternate_dimension.png"
	var texture: Texture2D = load(path)
	if texture == null:
		return
	for row: int in range(-2, 2):
		for column: int in range(2):
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.position = Vector2(700.0 + column * 1400.0, 360.0 + row * 720.0)
			sprite.scale = Vector2(1400.0 / texture.get_width(), 720.0 / texture.get_height())
			sprite.modulate = Color(0.52, 0.52, 0.58, 0.82)
			sprite.z_index = -20
			parent.add_child(sprite)

func _add_exit_door(position: Vector2) -> void:
	var door := Area2D.new()
	door.name = "ExitDoor"
	door.position = position
	door.collision_layer = 0
	door.collision_mask = 2
	door.body_entered.connect(_on_exit_door_entered)
	add_child(door)

	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/interactables/locked_door.png")
	sprite.position = Vector2(0, -49)
	sprite.scale = Vector2(140.0 / sprite.texture.get_width(), 140.0 / sprite.texture.get_height())
	sprite.z_index = -1
	door.add_child(sprite)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(100, 170)
	collision.shape = shape
	door.add_child(collision)

func _on_exit_door_entered(body: Node) -> void:
	if _exit_triggered or not body.is_in_group("player"):
		return
	_exit_triggered = true
	GameManager.complete_level()
	get_tree().call_deferred("change_scene_to_file", NEXT_LEVEL_PATH)
