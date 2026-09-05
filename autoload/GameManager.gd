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
	# SceneTreeTimer 掛在 SceneTree 上,換場不會取消它,receiver 又是 autoload ——
	# 所以死後一秒內若換過場(按了跳關鍵、或走進了門),這個計時器還是會醒來、
	# 把剛載入的新關卡莫名重載一次。reset_level_state() 會把旗標清成 false,
	# 而它在每個 LevelBase._ready() 與跳關時都會被呼叫,以此讓過期的計時器失效。
	if not restarting_level:
		return
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
