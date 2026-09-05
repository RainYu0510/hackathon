extends CharacterBody2D

enum State { IDLE, CHASE, ATTACK, HIT, DEAD }
var state := State.IDLE
var gravity := 1250.0
var target: Node2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hit_box: HitBox = $HitBox

func _ready() -> void:
	add_to_group("enemy")
	_build_animations()
	$HurtBox.hurt.connect(_on_hurt)
	health.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	if state == State.DEAD: return
	velocity.y += gravity * delta
	target = _nearest_player()
	if target and global_position.distance_to(target.global_position) < 430.0:
		var dx: float = target.global_position.x - global_position.x
		if absf(dx) < 65.0:
			_attack()
		else:
			state = State.CHASE
			velocity.x = sign(dx) * 90.0
			sprite.flip_h = velocity.x < 0.0
			sprite.play("run")
	else:
		state = State.IDLE
		velocity.x = move_toward(velocity.x, 0, 15)
		sprite.play("idle")
	move_and_slide()

func _nearest_player() -> Node2D:
	var best: Node2D
	var distance := INF
	for candidate in get_tree().get_nodes_in_group("player"):
		var d := global_position.distance_squared_to(candidate.global_position)
		if d < distance: distance = d; best = candidate
	return best

func _attack() -> void:
	if state == State.ATTACK or state == State.HIT: return
	state = State.ATTACK
	velocity.x = 0
	sprite.play("attack")
	await get_tree().create_timer(0.18).timeout
	hit_box.begin_attack()
	await get_tree().create_timer(0.16).timeout
	hit_box.end_attack()
	await get_tree().create_timer(0.3).timeout
	if state != State.DEAD: state = State.IDLE

func _on_hurt(amount: int, _source: Node) -> void:
	if state == State.DEAD: return
	health.damage(amount)
	if health.health > 0:
		state = State.HIT
		sprite.play("hit")
		await get_tree().create_timer(0.3).timeout
		state = State.IDLE

func _on_died() -> void:
	state = State.DEAD
	hit_box.end_attack()
	sprite.play("death")
	await get_tree().create_timer(0.8).timeout
	queue_free()

func _build_animations() -> void:
	var frames := SpriteFrames.new(); frames.remove_animation("default")
	var counts := {"idle":4,"run":6,"jump":5,"attack":5,"hit":4,"death":8}
	for anim in counts:
		frames.add_animation(anim); frames.set_animation_speed(anim, 9); frames.set_animation_loop(anim, anim in ["idle","run"])
		for i in range(1, counts[anim] + 1):
			var path := "res://assets/enemies/slime/%s/%s_%02d.png" % [anim, anim, i]
			if ResourceLoader.exists(path): frames.add_frame(anim, load(path))
	sprite.sprite_frames = frames; sprite.play("idle")

