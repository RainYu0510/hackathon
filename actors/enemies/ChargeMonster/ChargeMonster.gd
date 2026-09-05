extends CharacterBody2D

enum State { NORMAL, ANGRY, PREPARE_CHARGE, CHARGING, STUNNED, USED, DEAD }

## -1 = 追最近的玩家(原本的行為)。設成 0/1 就鎖定該 player_index。
## 謎題關卡需要鎖定 —— 否則另一名玩家剛好比較近時,怪物會往錯的方向衝。
@export var target_player_index := -1
## 0 = 不限距離(原本的行為)。設成正值時,目標超出這個距離就原地待機。
## 沒有這個的話怪物開場就會自己走到關卡另一端,「引誘」這個步驟會消失。
@export var chase_range := 0.0
## 平常(NORMAL)慢慢追蹤玩家的速度。
@export var normal_speed := 45.0
## 憤怒(ANGRY)時朝目標玩家衝去的速度,比平常追蹤快很多。
@export var angry_speed := 160.0

var state := State.NORMAL
var charge_used := false
var target: Node2D
var gravity := 1250.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_box: HitBox = $HitBox

func _ready() -> void:
	add_to_group("enemy")
	_build_animations()
	DimensionManager.dimension_changed.connect(_on_dimension_changed)
	_on_dimension_changed(DimensionManager.current_dimension)

func _physics_process(delta: float) -> void:
	velocity.y += gravity * delta
	if state == State.CHARGING:
		var before_x := global_position.x
		move_and_slide()
		for i in get_slide_collision_count():
			var collider := get_slide_collision(i).get_collider()
			if collider and collider.has_method("try_break"):
				collider.try_break(self)
				_finish_charge()
				return
		# 衝歪了撞到普通地形:velocity 被擋住,但狀態不會自己結束 ——
		# 原本會變成貼著牆一直抖、傷害判定永遠開著。這裡收尾。
		if absf(global_position.x - before_x) < 1.0:
			_finish_charge()
		return
	if state in [State.USED, State.STUNNED, State.DEAD]:
		move_and_slide(); return
	target = _select_target()
	if target and _within_chase_range(target):
		var dx := target.global_position.x - global_position.x
		var speed := angry_speed if state == State.ANGRY else normal_speed
		velocity.x = sign(dx) * speed
		sprite.flip_h = velocity.x < 0.0
		if state == State.ANGRY and absf(dx) > 150.0 and absf(dx) < 650.0:
			_prepare_charge(sign(dx))
	else:
		velocity.x = 0.0
	move_and_slide()

func _select_target() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty(): return null
	if target_player_index >= 0:
		for player in players:
			if player.player_index == target_player_index: return player
	var result: Node2D = players[0]
	for player in players:
		if global_position.distance_squared_to(player.global_position) < global_position.distance_squared_to(result.global_position): result = player
	return result

func _within_chase_range(node: Node2D) -> bool:
	return chase_range <= 0.0 or global_position.distance_to(node.global_position) <= chase_range

func _prepare_charge(direction: float) -> void:
	if charge_used or state == State.PREPARE_CHARGE: return
	state = State.PREPARE_CHARGE
	velocity.x = 0
	_apply_look()
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree() or charge_used: return
	if DimensionManager.current_dimension != DimensionManager.Dimension.ALTERNATE:
		# 蓄力途中被切回正常空間 → 衝刺取消。原本這裡是直接 return,state 會卡在
		# PREPARE_CHARGE 讓怪物永久凍住,要等下一次切維度才會被救回來。
		state = State.NORMAL
		_apply_look()
		return
	charge_used = true
	state = State.CHARGING
	add_to_group("charging_monster")
	velocity.x = direction * 720.0
	hit_box.begin_attack()
	_apply_look()

func _finish_charge() -> void:
	remove_from_group("charging_monster")
	state = State.USED
	velocity.x = 0
	hit_box.end_attack()
	_apply_look()
	collision_layer = 0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)

func _on_dimension_changed(value: DimensionManager.Dimension) -> void:
	if charge_used: return
	# 蓄力中不打斷,交給 _prepare_charge 自己在 0.8 秒後判斷,
	# 免得 state 被重設成 ANGRY 之後又被呼叫一次、跑出兩條 coroutine。
	if state == State.PREPARE_CHARGE: return
	state = State.ANGRY if value == DimensionManager.Dimension.ALTERNATE else State.NORMAL
	_apply_look()

## 顏色與貼圖都跟著狀態換。專案裡沒有衝刺怪的美術,借用史萊姆的動畫再上色。
func _apply_look() -> void:
	var tint := Color("8a72d7")
	var anim := "idle"
	match state:
		State.ANGRY: tint = Color("ff5577"); anim = "run"
		State.PREPARE_CHARGE: tint = Color("fff06a"); anim = "run"
		State.CHARGING: tint = Color("ff304f"); anim = "run"
		State.USED: tint = Color("777777")
	$Polygon2D.color = tint
	if sprite:
		sprite.modulate = tint
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim): sprite.play(anim)

func _build_animations() -> void:
	var frames := SpriteFrames.new(); frames.remove_animation("default")
	var counts := {"idle":4,"run":6}
	for anim in counts:
		frames.add_animation(anim); frames.set_animation_speed(anim, 9); frames.set_animation_loop(anim, true)
		for i in range(1, counts[anim] + 1):
			var path := "res://assets/enemies/slime/%s/%s_%02d.png" % [anim, anim, i]
			if ResourceLoader.exists(path): frames.add_frame(anim, load(path))
	sprite.sprite_frames = frames
	# 素材若不在,就退回原本的純色方塊,不會變成看不見的怪物。
	var has_art := frames.get_frame_count("idle") > 0
	sprite.visible = has_art
	$Polygon2D.visible = not has_art
