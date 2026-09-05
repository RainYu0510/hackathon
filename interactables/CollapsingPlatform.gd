extends AnimatableBody2D

enum State { STABLE, SHAKING, FALLING, GONE }
@export var delay := 0.0
var state := State.STABLE
var origin := Vector2.ZERO

func _ready() -> void:
	origin = position

func trigger() -> void:
	if state != State.STABLE: return
	await get_tree().create_timer(delay).timeout
	state = State.SHAKING
	for i in range(12):
		position.x = origin.x + (-4 if i % 2 == 0 else 4)
		await get_tree().create_timer(0.05).timeout
	position.x = origin.x
	state = State.FALLING
	$CollisionShape2D.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + 500, 1.0)
	await tween.finished
	state = State.GONE
	queue_free()

