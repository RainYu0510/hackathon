extends Node

signal key_collected
signal checkpoint_changed(position: Vector2)
signal level_completed

var has_key := false
var checkpoint_position := Vector2(180, 560)
var level_complete := false
var restarting_level := false

func reset_level_state() -> void:
	has_key = false
	level_complete = false
	restarting_level = false
	checkpoint_position = Vector2(180, 560)
	DimensionManager.reset()

func restart_level() -> void:
	if restarting_level:
		return
	restarting_level = true
	# Remove every global value that could satisfy a completion condition
	# immediately, then reload the scene to recreate all level objects.
	has_key = false
	level_complete = false
	checkpoint_position = Vector2(180, 560)
	DimensionManager.reset()
	get_tree().create_timer(1.0).timeout.connect(_finish_level_restart, CONNECT_ONE_SHOT)

func _finish_level_restart() -> void:
	get_tree().reload_current_scene()

func collect_key() -> void:
	if has_key:
		return
	has_key = true
	key_collected.emit()

func set_checkpoint(value: Vector2) -> void:
	checkpoint_position = value
	checkpoint_changed.emit(value)

func respawn_all() -> void:
	for player in get_tree().get_nodes_in_group("player"):
		player.respawn(checkpoint_position + Vector2(player.player_index * 50, 0))

func complete_level() -> void:
	level_complete = true
	level_completed.emit()
