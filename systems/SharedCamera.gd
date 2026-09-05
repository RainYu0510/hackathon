extends Camera2D

@export var smooth_speed := 5.0

func _process(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() < 2: return
	var midpoint: Vector2 = (players[0].global_position + players[1].global_position) * 0.5
	global_position = global_position.lerp(midpoint - Vector2(0,100), clampf(delta * smooth_speed, 0, 1))

