class_name PlayerBase
extends CharacterBody2D

signal goggle_acquired(player: PlayerBase)
@export var player_index := 0
@export var asset_root := "res://assets/characters/noxcat"
@export var special_animation := "goggle"
@export var move_speed := 230.0
@export var jump_velocity := -560.0
@export var max_separation := 820.0
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.14
var has_goggle := false
var facing := 1.0
var attacking := false
var special_playing := false
var hurt_playing := false
var dead := false
var gravity := 1325.0
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var fallback_jump_was_down := false
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_box: HitBox = $HitBox
@onready var hurt_box: HurtBox = $HurtBox
@onready var health: HealthComponent = $HealthComponent

func _ready() -> void:
	add_to_group("player")
	_build_animations()
	hurt_box.hurt.connect(_on_hurt)
	health.died.connect(_on_died)
	sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	if dead:
		velocity.y += gravity * delta
		move_and_slide()
		return
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)
		velocity.y += gravity * delta * (1.12 if velocity.y > 0.0 else 1.0)
	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	var prefix := "p%d_" % (player_index + 1)
	var axis := Input.get_axis(prefix + "left", prefix + "right")
	# Keyboard fallback keeps Player 2 responsive even when imported InputMap
	# keycodes differ between platforms or keyboard layouts.
	if player_index == 1:
		axis = Input.get_axis("p2_left", "p2_right")
		if Input.is_key_pressed(KEY_LEFT): axis = -1.0
		elif Input.is_key_pressed(KEY_RIGHT): axis = 1.0
	if _would_exceed_separation(axis):
		axis = 0.0
	velocity.x = move_toward(velocity.x, axis * move_speed, 45.0)
	if axis != 0.0:
		facing = sign(axis)
		sprite.flip_h = facing < 0.0
		hit_box.position.x = absf(hit_box.position.x) * facing
	var jump_pressed := Input.is_action_just_pressed(prefix + "jump")
	if player_index == 1:
		var fallback_jump_down := Input.is_key_pressed(KEY_UP)
		jump_pressed = jump_pressed or (fallback_jump_down and not fallback_jump_was_down)
		fallback_jump_was_down = fallback_jump_down
	if jump_pressed:
		jump_buffer_timer = jump_buffer_time
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
	if Input.is_action_just_pressed(prefix + "attack") and not attacking:
		_start_attack()
	if Input.is_action_just_pressed(prefix + "interact"):
		if has_goggle:
			_play_special()
			DimensionManager.toggle()
		else:
			_try_interact()
	move_and_slide()
	_update_animation()

func _would_exceed_separation(axis: float) -> bool:
	if axis == 0.0:
		return false
	for other in get_tree().get_nodes_in_group("player"):
		if other != self:
			var gap: float = global_position.x - other.global_position.x
			return absf(gap) >= max_separation and sign(gap) == sign(axis)
	return false

func _try_interact() -> void:
	for area in $InteractionDetector.get_overlapping_areas():
		if area.has_method("interact"):
			area.interact(self)
			return

func acquire_goggle() -> void:
	has_goggle = true
	_play_special()
	goggle_acquired.emit(self)

func _start_attack() -> void:
	attacking = true
	sprite.play("attack")
	await get_tree().create_timer(0.12).timeout
	if not dead:
		hit_box.begin_attack()
	await get_tree().create_timer(0.16).timeout
	hit_box.end_attack()

func _play_special() -> void:
	special_playing = true
	sprite.play(special_animation)
	if special_animation == "goggle":
		_play_goggle_flash()

func _play_goggle_flash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.25, 1.0, 0.35, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	get_tree().current_scene.add_child(layer)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.22, 0.08)
	tween.tween_property(flash, "color:a", 0.0, 0.28)
	tween.tween_callback(layer.queue_free)

func _on_hurt(amount: int, _source: Node) -> void:
	if dead or hurt_box.invulnerable:
		return
	health.damage(amount)
	if health.health > 0:
		hurt_playing = true
		hurt_box.invulnerable = true
		sprite.play("hit")
		await get_tree().create_timer(0.7).timeout
		hurt_box.invulnerable = false

func _on_died() -> void:
	dead = true
	hit_box.end_attack()
	sprite.play("death")
	GameManager.restart_level()

func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	dead = false
	attacking = false
	hurt_playing = false
	health.restore()
	sprite.play("idle")

func _on_animation_finished() -> void:
	if sprite.animation == "attack": attacking = false
	if sprite.animation == special_animation: special_playing = false
	if sprite.animation == "hit": hurt_playing = false

func _update_animation() -> void:
	if dead or hurt_playing or attacking or special_playing:
		return
	if not is_on_floor(): sprite.play("jump")
	elif absf(velocity.x) > 15.0: sprite.play("run")
	else: sprite.play("idle")

func _build_animations() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var animation_counts := {"idle":4,"run":8,"jump":5,"attack":5,special_animation:4,"hit":4,"death":7}
	for anim in animation_counts:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 9.0)
		frames.set_animation_loop(anim, anim in ["idle", "run"])
		for i in range(1, animation_counts[anim] + 1):
			var path := "%s/%s/%s_%02d.png" % [asset_root, anim, anim, i]
			if ResourceLoader.exists(path): frames.add_frame(anim, load(path))
	sprite.sprite_frames = frames
	sprite.play("idle")
