extends LevelBase

# 第三關 —— 衝刺怪撞破牆。地形是一個凹槽:
#   左邊是高平台(安全區,怪物上不來),中間是凹槽底,右邊是一堵頂天立地的高牆,
#   只有下面那一段是脆弱牆體。門在牆後面,破牆之前到不了。
#
# 解法:狗下凹槽把怪物往左引開 -> 狗穿過怪物跑到牆與怪物之間 ->
#       貓留在高平台上按 G 切異空間 -> 怪物憤怒蓄力後往右衝 ->
#       狗跳起來閃開 -> 怪物撞破脆弱牆體 -> 兩人穿過破口走進門。
#
# 破牆本身不算過關(它只是打開通路),過關條件是走進門。

const GROUND_TOP := 600.0

var wall: StaticBody2D

func build_level() -> void:
	# 第四關內容尚未定案。定了之後只要把場景路徑填在這裡就自動接上。
	next_scene_path = ""

	var normal:=Node2D.new(); normal.name="NormalWorld"; normal.set_script(load("res://systems/DimensionWorld.gd")); normal.set("dimension", DimensionManager.Dimension.NORMAL)
	var alternate:=Node2D.new(); alternate.name="AlternateWorld"; alternate.set_script(load("res://systems/DimensionWorld.gd")); alternate.set("dimension", DimensionManager.Dimension.ALTERNATE)
	dimension_background(normal, false)
	dimension_background(alternate, true)
	add_child(normal); add_child(alternate)

	# ── 地形 ──────────────────────────────────────────────
	platform(self, Vector2(1250,640), Vector2(2700,80), Color("3f435b"))  # 凹槽底 x[-100,2600] 頂面 600
	platform(self, Vector2(450,545), Vector2(1100,110), Color("545b76"))  # 高平台 x[-100,1000] 頂面 490
	platform(self, Vector2(1075,572), Vector2(150,55), Color("545b76"))   # 階梯   x[1000,1150] 頂面 545
	# 左右邊界:純碰撞、不畫圖。有了它們就不可能走出地圖掉進 DeathZone,
	# 這一關才真的「沒有機會掉下去」。
	_boundary(Vector2(-130,200), Vector2(60,800))
	_boundary(Vector2(2610,200), Vector2(60,800))

	# ── 玩家:出生在高平台上,只有貓有護目鏡 ──────────────────
	spawn_players(Vector2(170,450), Vector2(240,450))
	for player in get_tree().get_nodes_in_group("player"):
		player.has_goggle = player.player_index == 0
	checkpoint(Vector2(170,490))

	# ── 右邊那堵頂天立地的高牆 ────────────────────────────
	_tall_wall(Vector2(2160,100), Vector2(120,600))      # 實心段 y[-200,400],撞不破
	wall = _make_wall(Vector2(2160,500), Vector2(120,200))  # 脆弱段 y[400,600],撞破後是通路
	wall.connect("wall_broken", _on_wall_broken)

	# ── 史萊姆:平常在凹槽右半來回巡邏,誰下凹槽就追誰 ──────────
	var monster := preload("res://actors/enemies/ChargeMonster/ChargeMonster.tscn").instantiate()
	monster.position = Vector2(1950,595)
	monster.chase_range = 520.0         # 狗靠近才跟,否則牠開場就自己走到左端,引誘步驟會消失
	# 索敵改用高度帶(預設 80):高平台頂面 490、凹槽底頂面 600,差 110,
	# 所以貓待在高平台上不會被鎖定,不必再硬鎖 target_player_index。
	# 巡邏範圍:左界留在階梯(x[1000,1150])右邊,右界留在牆(x=2100 起)前面。
	monster.patrol_min_x = 1400.0
	monster.patrol_max_x = 2050.0
	add_child(monster)

	# ── 門:在牆後面,破牆之前到不了 ────────────────────────
	checkpoint(Vector2(2400,GROUND_TOP))
	exit_trigger(Vector2(2400,530), Vector2(100,170))

	var title:=Label.new(); title.text="LEVEL 03 - lure the monster away, then let it charge into the cracked wall"; title.position=Vector2(220,70); title.add_theme_font_size_override("font_size",20); $HUD.add_child(title)

func _boundary(pos: Vector2, size: Vector2) -> void:
	var body:=StaticBody2D.new(); body.position=pos; body.collision_layer=1; body.collision_mask=0; add_child(body)
	var cs:=CollisionShape2D.new(); var shape:=RectangleShape2D.new(); shape.size=size; cs.shape=shape; body.add_child(cs)

func _tall_wall(pos: Vector2, size: Vector2) -> void:
	var body:=StaticBody2D.new(); body.position=pos; body.collision_layer=1; body.collision_mask=0; add_child(body)
	var sprite:=Sprite2D.new(); sprite.texture=load("res://assets/interactables/tall_wall_side.png")
	sprite.scale=Vector2(size.x/sprite.texture.get_width(), size.y/sprite.texture.get_height()); sprite.z_index=4; body.add_child(sprite)
	var cs:=CollisionShape2D.new(); var shape:=RectangleShape2D.new(); shape.size=size; cs.shape=shape; body.add_child(cs)

func _make_wall(pos: Vector2, size: Vector2) -> StaticBody2D:
	var body:=StaticBody2D.new(); body.position=pos; body.collision_layer=1; body.set_script(load("res://interactables/BreakableWall.gd"))
	var half:=size*0.5
	var poly:=Polygon2D.new(); poly.name="Polygon2D"; poly.polygon=PackedVector2Array([Vector2(-half.x,-half.y),Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)]); body.add_child(poly)
	var cs:=CollisionShape2D.new(); cs.name="CollisionShape2D"; var shape:=RectangleShape2D.new(); shape.size=size; cs.shape=shape; body.add_child(cs)
	add_child(body)
	return body

func _on_wall_broken() -> void:
	# 破牆只是打開通路,不是過關 —— 過關條件是走進牆後面那道門。
	var hint:=Label.new(); hint.text="The wall is down. Head through the gap to the door."; hint.position=Vector2(330,110); hint.add_theme_font_size_override("font_size",18); $HUD.add_child(hint)
