extends LevelBase

var wall: StaticBody2D

func build_level() -> void:
	GameManager.checkpoint_position = Vector2(170,560)
	spawn_players(Vector2(170,560),Vector2(240,560))
	for player in get_tree().get_nodes_in_group("player"):
		player.has_goggle = true
	platform(self,Vector2(1000,640),Vector2(2000,80),Color("3f435b"))
	platform(self,Vector2(900,500),Vector2(260,30),Color("545b76"))
	wall = _make_wall(Vector2(1450,505))
	var monster:=preload("res://actors/enemies/ChargeMonster/ChargeMonster.tscn").instantiate(); monster.position=Vector2(1030,590); add_child(monster)
	checkpoint(Vector2(170,600))
	var title:=Label.new(); title.text="LEVEL 04 — lure the angry monster into the wall (one charge only)"; title.position=Vector2(350,70); title.add_theme_font_size_override("font_size",20); $HUD.add_child(title)

func _make_wall(pos:Vector2)->StaticBody2D:
	var body:=StaticBody2D.new(); body.position=pos; body.collision_layer=1; body.set_script(load("res://interactables/BreakableWall.gd"))
	var poly:=Polygon2D.new(); poly.name="Polygon2D"; poly.polygon=PackedVector2Array([Vector2(-35,-135),Vector2(35,-135),Vector2(35,135),Vector2(-35,135)]); body.add_child(poly)
	var cs:=CollisionShape2D.new(); cs.name="CollisionShape2D"; var shape:=RectangleShape2D.new(); shape.size=Vector2(70,270); cs.shape=shape; body.add_child(cs)
	body.connect("wall_broken", GameManager.complete_level)
	add_child(body)
	return body
