extends LevelBase

func build_level() -> void:
	spawn_players(Vector2(170,560),Vector2(240,560))
	checkpoint(Vector2(150,600)); pickup(Vector2(360,545))
	var shared:=Node2D.new(); shared.name="SharedObjects"; add_child(shared)
	platform(shared,Vector2(300,640),Vector2(600,80),Color("334463")); platform(shared,Vector2(2100,640),Vector2(550,80),Color("334463")); platform(shared,Vector2(3300,640),Vector2(700,80),Color("334463"))
	var normal:=Node2D.new(); normal.name="NormalWorld"; normal.set_script(load("res://systems/DimensionWorld.gd")); normal.set("dimension", DimensionManager.Dimension.NORMAL)
	var alternate:=Node2D.new(); alternate.name="AlternateWorld"; alternate.set_script(load("res://systems/DimensionWorld.gd")); alternate.set("dimension", DimensionManager.Dimension.ALTERNATE)
	dimension_background(normal, false)
	dimension_background(alternate, true)
	platform(normal,Vector2(760,590),Vector2(220,35),Color("4384a8")); platform(alternate,Vector2(1050,530),Vector2(210,35),Color("b353d1")); platform(normal,Vector2(1325,470),Vector2(190,35),Color("4384a8")); platform(alternate,Vector2(1600,535),Vector2(210,35),Color("b353d1")); platform(normal,Vector2(1840,580),Vector2(180,35),Color("4384a8")); platform(alternate,Vector2(2440,545),Vector2(220,35),Color("b353d1")); platform(normal,Vector2(2700,470),Vector2(210,35),Color("4384a8")); platform(alternate,Vector2(2950,545),Vector2(190,35),Color("b353d1"))
	add_child(normal); add_child(alternate)
	checkpoint(Vector2(2050,590)); checkpoint(Vector2(2960,590)); pickup(Vector2(3190,560),true)
	for i in range(5):
		var p:=_collapse(Vector2(3420+i*125,610),i*0.28); collapse_platforms.append(p)
	var slime:=preload("res://actors/enemies/Slime/Slime.tscn").instantiate(); slime.position=Vector2(2180,590); add_child(slime)
	var exit:=Area2D.new(); exit.position=Vector2(4020,550); exit.collision_mask=2; exit.body_entered.connect(_on_exit_entered); add_child(exit)
	var ep:=Polygon2D.new(); ep.polygon=PackedVector2Array([Vector2(-35,-90),Vector2(35,-90),Vector2(35,0),Vector2(-35,0)]); ep.color=Color("65f28b"); exit.add_child(ep); var ecs:=CollisionShape2D.new(); var es:=RectangleShape2D.new(); es.size=Vector2(80,180); ecs.shape=es; exit.add_child(ecs)

func _collapse(pos:Vector2,delay:float)->AnimatableBody2D:
	var body:=AnimatableBody2D.new(); body.position=pos; body.collision_layer=1; body.set_script(load("res://interactables/CollapsingPlatform.gd")); body.set("delay", delay); add_child(body)
	var poly:=Polygon2D.new(); poly.polygon=PackedVector2Array([Vector2(-58,-15),Vector2(58,-15),Vector2(58,15),Vector2(-58,15)]); poly.color=Color("bb7655"); body.add_child(poly)
	var cs:=CollisionShape2D.new(); cs.name="CollisionShape2D"; var shape:=RectangleShape2D.new(); shape.size=Vector2(116,30); cs.shape=shape; body.add_child(cs); return body

func _on_exit_entered(body: Node) -> void:
	if body.is_in_group("player") and GameManager.has_key:
		GameManager.complete_level()
