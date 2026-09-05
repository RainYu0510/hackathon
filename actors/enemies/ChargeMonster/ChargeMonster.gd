extends CharacterBody2D

enum State { NORMAL, ANGRY, PREPARE_CHARGE, CHARGING, STUNNED, USED, DEAD }
var state := State.NORMAL
var charge_used := false
var target: Node2D
var gravity := 1250.0

func _ready() -> void:
	add_to_group("enemy")
	DimensionManager.dimension_changed.connect(_on_dimension_changed)
	_on_dimension_changed(DimensionManager.current_dimension)

func _physics_process(delta: float) -> void:
	velocity.y += gravity * delta
	if state == State.CHARGING:
		move_and_slide()
		for i in get_slide_collision_count():
			var collider := get_slide_collision(i).get_collider()
			if collider and collider.has_method("try_break"):
				collider.try_break(self)
				_finish_charge()
		return
	if state in [State.USED, State.STUNNED, State.DEAD]:
		move_and_slide(); return
	target = _select_target()
	if target:
		var dx := target.global_position.x - global_position.x
		velocity.x = sign(dx) * 70.0
		if state == State.ANGRY and absf(dx) > 150.0 and absf(dx) < 650.0:
			_prepare_charge(sign(dx))
	move_and_slide()

func _select_target() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty(): return null
	var result: Node2D = players[0]
	for player in players:
		if global_position.distance_squared_to(player.global_position) < global_position.distance_squared_to(result.global_position): result = player
	return result

func _prepare_charge(direction: float) -> void:
	if charge_used or state == State.PREPARE_CHARGE: return
	state = State.PREPARE_CHARGE
	velocity.x = 0
	$Polygon2D.color = Color("fff06a")
	await get_tree().create_timer(0.8).timeout
	if DimensionManager.current_dimension != DimensionManager.Dimension.ALTERNATE or charge_used: return
	charge_used = true
	state = State.CHARGING
	add_to_group("charging_monster")
	velocity.x = direction * 720.0
	$Polygon2D.color = Color("ff304f")

func _finish_charge() -> void:
	remove_from_group("charging_monster")
	state = State.USED
	velocity.x = 0
	$Polygon2D.color = Color("777777")

func _on_dimension_changed(value: DimensionManager.Dimension) -> void:
	if charge_used: return
	state = State.ANGRY if value == DimensionManager.Dimension.ALTERNATE else State.NORMAL
	$Polygon2D.color = Color("ff5577") if state == State.ANGRY else Color("8a72d7")

