extends LevelBase

func build_level() -> void:
	spawn_players(Vector2(170,560),Vector2(240,560))
	checkpoint(Vector2(150,600)); pickup(Vector2(360,545))
	var shared:=Node2D.new(); shared.name="SharedObjects"; add_child(shared)
	platform(shared,Vector2(300,640),Vector2(600,80),Color("334463"))
	platform(shared,Vector2(1900,500),Vector2(300,45),Color("334463"))
	var normal:=Node2D.new(); normal.name="NormalWorld"; normal.set_script(load("res://systems/DimensionWorld.gd")); normal.set("dimension", DimensionManager.Dimension.NORMAL)
	var alternate:=Node2D.new(); alternate.name="AlternateWorld"; alternate.set_script(load("res://systems/DimensionWorld.gd")); alternate.set("dimension", DimensionManager.Dimension.ALTERNATE)
	dimension_background(normal, false)
	dimension_background(alternate, true)
	platform(normal,Vector2(720,580),Vector2(220,35),Color("4384a8"))
	platform(alternate,Vector2(1020,515),Vector2(220,35),Color("b353d1"))
	platform(normal,Vector2(1320,445),Vector2(220,35),Color("4384a8"))
	platform(alternate,Vector2(1615,500),Vector2(220,35),Color("b353d1"))
	add_child(normal); add_child(alternate)
	pickup(Vector2(1900,440),true)
	var end_wall:=StaticBody2D.new(); end_wall.position=Vector2(2110,237.5); end_wall.collision_layer=1; end_wall.collision_mask=0; add_child(end_wall)
	var wall_sprite:=Sprite2D.new(); wall_sprite.texture=load("res://assets/interactables/tall_wall_side.png"); var wall_scale:=480.0/wall_sprite.texture.get_height(); wall_sprite.scale=Vector2(wall_scale,wall_scale); wall_sprite.position=Vector2(-55,12); wall_sprite.z_index=4; end_wall.add_child(wall_sprite)
	var wall_collision:=CollisionShape2D.new(); var wall_shape:=RectangleShape2D.new(); wall_shape.size=Vector2(120,480); wall_collision.shape=wall_shape; end_wall.add_child(wall_collision)
	var door_trigger:=Area2D.new(); door_trigger.position=Vector2(150,530); door_trigger.collision_layer=0; door_trigger.collision_mask=2; door_trigger.body_entered.connect(_on_door_entered); add_child(door_trigger)
	var door_shape:=CollisionShape2D.new(); var door_rect:=RectangleShape2D.new(); door_rect.size=Vector2(100,170); door_shape.shape=door_rect; door_trigger.add_child(door_shape)

func _collapse(pos:Vector2,delay:float)->AnimatableBody2D:
	var body:=AnimatableBody2D.new(); body.position=pos; body.collision_layer=1; body.set_script(load("res://interactables/CollapsingPlatform.gd")); body.set("delay", delay); add_child(body)
	var poly:=Polygon2D.new(); poly.polygon=PackedVector2Array([Vector2(-58,-15),Vector2(58,-15),Vector2(58,15),Vector2(-58,15)]); poly.color=Color("bb7655"); body.add_child(poly)
	var cs:=CollisionShape2D.new(); cs.name="CollisionShape2D"; var shape:=RectangleShape2D.new(); shape.size=Vector2(116,30); cs.shape=shape; body.add_child(cs); return body

func _on_door_entered(body: Node) -> void:
	if body.is_in_group("player") and GameManager.has_key:
		GameManager.complete_level()
		get_tree().call_deferred("change_scene_to_file", "res://levels/Level02_PLACEHOLDER.tscn")
