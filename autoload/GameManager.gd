extends Node

signal key_collected
signal checkpoint_changed(position: Vector2)
signal level_completed

var has_key := false
var checkpoint_position := Vector2(180, 560)
var level_complete := false

func reset_level_state() -> void:
	has_key = false
	level_complete = false
	checkpoint_position = Vector2(180, 560)
	DimensionManager.reset()

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

