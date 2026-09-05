extends CharacterBody2D

## 第三關的史萊姆(借用史萊姆美術的衝刺怪)。
##
## 行為:
##   PATROL  沒偵測到目標時在巡邏範圍內來回走,碰到牆或走到邊界就轉身
##   CHASE   偵測到「跟自己同一層」的玩家才追 —— 站在高平台上的貓是安全的
##   PREPARE 貓切到異空間會激怒牠,激怒狀態下跟目標拉開一段距離就蓄力
##   CHARGE  往目標方向高速衝刺,撞破脆弱牆 → DEAD;撞到普通地形 → STUNNED
##   STUNNED 暈眩一下回到 PATROL,冷卻過後可以再衝一次(不會卡關)
##   DEAD    播完死亡動畫就 queue_free 消失
##
## 「憤怒」是獨立於狀態機的旗標,不是一個狀態 —— 切維度只改旗標,
## 不會覆寫移動狀態,所以不再需要「別跑出兩條 coroutine」那種特例。
## 蓄力/暈眩的計時也全部走 _physics_process 的 delta 累加,不用 await,
## 避免 coroutine 跟狀態切換賽跑。

enum State { PATROL, CHASE, PREPARE, CHARGE, STUNNED, DEAD }

## -1 = 不硬鎖,誰跟牠同一層就追誰。設成 0/1 才鎖定該 player_index。
@export var target_player_index := -1
## 0 = 不限距離。設成正值時,水平距離超過就偵測不到。
@export var chase_range := 0.0
## 只有 y 差在這個帶內的玩家會被偵測到。第三關高平台頂面 y=490、
## 凹槽底頂面 y=600,差 110,所以 80 剛好把「站在高平台上」切成安全。
@export var detect_height_band := 80.0
## 目標跳起來暫時離開高度帶時的寬限,免得玩家一跳就被跟丟。
@export var target_lost_grace := 0.6
## 巡邏範圍。兩個都留 0 時以出生點 ±300 自動推算。
@export var patrol_min_x := 0.0
@export var patrol_max_x := 0.0
@export var patrol_speed := 50.0
@export var chase_speed := 95.0
@export var charge_speed := 720.0
@export var stun_time := 1.5

const PREPARE_TIME := 0.8
const CHARGE_COOLDOWN := 0.6      # 暈眩結束後多久才能再蓄力
const CHARGE_MIN_GAP := 150.0
const CHARGE_MAX_GAP := 650.0
const CHARGE_STALL_GRACE := 0.1   # 起衝後多久才開始判定「卡住了」

var state := State.PATROL
var enraged := false
var target: PlayerBase
var patrol_direction := 1.0
var gravity := 1250.0
var _state_timer := 0.0
var _lost_timer := 0.0
var _cooldown_timer := 0.0
var _charge_direction := 1.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_box: HitBox = $HitBox

func _ready() -> void:
	add_to_group("enemy")
	_build_animations()
	if patrol_min_x == 0.0 and patrol_max_x == 0.0:
		patrol_min_x = global_position.x - 300.0
		patrol_max_x = global_position.x + 300.0
	DimensionManager.dimension_changed.connect(_on_dimension_changed)
	enraged = DimensionManager.current_dimension == DimensionManager.Dimension.ALTERNATE
	_apply_look()

func _physics_process(delta: float) -> void:
	_state_timer += delta
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	velocity.y += gravity * delta
	match state:
		State.DEAD:
			velocity.x = 0.0
			move_and_slide()
		State.CHARGE:
			_process_charge()
		State.STUNNED:
			velocity.x = 0.0
			move_and_slide()
			if _state_timer >= stun_time:
				_enter_patrol()
		State.PREPARE:
			velocity.x = 0.0
			move_and_slide()
			if _state_timer >= PREPARE_TIME:
				_launch_charge()
		_:
			_process_ground(delta)

## ─── 地面移動:巡邏 / 追擊 ─────────────────────────────────
func _process_ground(delta: float) -> void:
	_update_target(delta)
	if target:
		if state != State.CHASE:
			state = State.CHASE
			_state_timer = 0.0
			_apply_look()
		var dx := target.global_position.x - global_position.x
		if _can_charge(dx):
			_enter_prepare(signf(dx))
			return
		velocity.x = signf(dx) * chase_speed
	else:
		if state != State.PATROL:
			_enter_patrol()
		_patrol_step()
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0
	move_and_slide()
	# 巡邏撞到牆就轉身。放在 move_and_slide() 之後才有正確的 is_on_wall()。
	if state == State.PATROL and is_on_wall():
		patrol_direction = -patrol_direction

func _patrol_step() -> void:
	if global_position.x <= patrol_min_x:
		patrol_direction = 1.0
	elif global_position.x >= patrol_max_x:
		patrol_direction = -1.0
	velocity.x = patrol_direction * patrol_speed

func _enter_patrol() -> void:
	state = State.PATROL
	_state_timer = 0.0
	_apply_look()

## ─── 索敵 ────────────────────────────────────────────────
func _update_target(delta: float) -> void:
	var found := _detect_target()
	if found:
		target = found
		_lost_timer = 0.0
		return
	if not is_instance_valid(target):
		target = null
		return
	# 玩家跳起來會暫時離開高度帶(跳躍最高約 159px),給一段寬限再放掉,
	# 不然怪物會在玩家每次起跳時抽動一下。
	_lost_timer += delta
	if _lost_timer >= target_lost_grace:
		target = null

## 只鎖定「跟自己同一層」的玩家:y 差在 detect_height_band 內、
## 且水平距離在 chase_range 內。多人符合就取水平最近的。
func _detect_target() -> PlayerBase:
	var best: PlayerBase = null
	var best_distance := INF
	for candidate: Node in get_tree().get_nodes_in_group("player"):
		var player := candidate as PlayerBase
		if player == null or player.dead:
			continue
		if target_player_index >= 0 and player.player_index != target_player_index:
			continue
		if absf(player.global_position.y - global_position.y) > detect_height_band:
			continue
		var distance := absf(player.global_position.x - global_position.x)
		if chase_range > 0.0 and distance > chase_range:
			continue
		if distance < best_distance:
			best_distance = distance
			best = player
	return best

## ─── 蓄力與衝刺 ──────────────────────────────────────────
func _can_charge(dx: float) -> bool:
	return enraged and _cooldown_timer <= 0.0 and is_on_floor() \
		and absf(dx) > CHARGE_MIN_GAP and absf(dx) < CHARGE_MAX_GAP

func _enter_prepare(direction: float) -> void:
	state = State.PREPARE
	_state_timer = 0.0
	_charge_direction = direction
	velocity.x = 0.0
	sprite.flip_h = direction < 0.0
	_apply_look()

func _launch_charge() -> void:
	if not enraged:
		# 蓄力途中被切回常態空間 → 取消。回巡邏而不是卡在 PREPARE,
		# 下一幀就會重新索敵,貓再切一次空間還能再誘一次。
		_cooldown_timer = CHARGE_COOLDOWN
		_enter_patrol()
		return
	state = State.CHARGE
	_state_timer = 0.0
	add_to_group("charging_monster")   # BreakableWall.try_break() 認的就是這個 group
	velocity.x = _charge_direction * charge_speed
	hit_box.begin_attack()
	_apply_look()

func _process_charge() -> void:
	var before_x := global_position.x
	move_and_slide()
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider and collider.has_method("try_break") and collider.try_break(self):
			_die()
			return
	# 撞到普通地形:velocity 被擋住,但狀態不會自己結束 —— 原本會貼著牆一直抖、
	# 傷害判定永遠開著。停滯判定不能只看「本幀位移 < 1px」:起衝第一幀與騰空
	# 被卡都會誤觸,所以加上 is_on_wall() 與一小段起衝寬限。
	if is_on_wall() or (_state_timer > CHARGE_STALL_GRACE and absf(global_position.x - before_x) < 1.0):
		_stun()

## 衝歪了不是關卡結束 —— 暈眩一下回到巡邏,冷卻過後可以再衝一次。
## 原本這裡是 charge_used = true 且永不重置,衝歪就 soft-lock,只能按 R 重來。
func _stun() -> void:
	remove_from_group("charging_monster")
	state = State.STUNNED
	_state_timer = 0.0
	velocity.x = 0.0
	hit_box.end_attack()
	_cooldown_timer = stun_time + CHARGE_COOLDOWN
	_apply_look()

## 撞破牆 = 任務完成,播死亡動畫後消失,不留一具灰色墓碑在場上。
func _die() -> void:
	remove_from_group("charging_monster")
	state = State.DEAD
	_state_timer = 0.0
	velocity.x = 0.0
	hit_box.end_attack()
	hit_box.set_deferred("monitoring", false)
	_apply_look()
	if sprite.sprite_frames and sprite.sprite_frames.get_frame_count("death") > 0:
		await sprite.animation_finished
	else:
		await get_tree().create_timer(0.6).timeout
	queue_free()

func _on_dimension_changed(value: DimensionManager.Dimension) -> void:
	# 只改旗標,不碰 state。蓄力中被切回常態空間由 _launch_charge() 自己判斷。
	enraged = value == DimensionManager.Dimension.ALTERNATE
	if state == State.DEAD:
		return
	_apply_look()

## 顏色與貼圖都跟著狀態換。專案裡沒有衝刺怪的美術,借用史萊姆的動畫再上色。
func _apply_look() -> void:
	var tint := Color("8a72d7")
	var anim := "idle"
	match state:
		State.PATROL, State.CHASE:
			anim = "run"
			if enraged:
				tint = Color("ff5577")
		State.PREPARE:
			tint = Color("fff06a"); anim = "run"
		State.CHARGE:
			tint = Color("ff304f"); anim = "run"
		State.STUNNED:
			tint = Color("7fa0c8"); anim = "hit"
		State.DEAD:
			tint = Color("777777"); anim = "death"
	$Polygon2D.color = tint
	if sprite:
		sprite.modulate = tint
		if sprite.sprite_frames and sprite.sprite_frames.get_frame_count(anim) > 0:
			sprite.play(anim)

func _build_animations() -> void:
	var frames := SpriteFrames.new(); frames.remove_animation("default")
	var counts: Dictionary[String, int] = {"idle":4,"run":6,"hit":4,"death":8}
	for anim: String in counts:
		frames.add_animation(anim); frames.set_animation_speed(anim, 9); frames.set_animation_loop(anim, anim in ["idle","run"])
		for i in range(1, counts[anim] + 1):
			var path := "res://assets/enemies/slime/%s/%s_%02d.png" % [anim, anim, i]
			if ResourceLoader.exists(path): frames.add_frame(anim, load(path))
	sprite.sprite_frames = frames
	# 素材若不在,就退回原本的純色方塊,不會變成看不見的怪物。
	var has_art := frames.get_frame_count("idle") > 0
	sprite.visible = has_art
	$Polygon2D.visible = not has_art
