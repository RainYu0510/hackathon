extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func interact(_player: PlayerBase) -> void:
	_collect()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"): _collect()

func _collect() -> void:
	if GameManager.has_key: return
	GameManager.collect_key()
	queue_free()

