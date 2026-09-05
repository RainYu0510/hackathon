extends Area2D

@export var spawn_offset := Vector2(0,-40)
var active := false

func _ready() -> void:
	add_to_group("checkpoint")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not active:
		active = true
		$Polygon2D.color = Color("62e6a5")
		GameManager.set_checkpoint(global_position + spawn_offset)

