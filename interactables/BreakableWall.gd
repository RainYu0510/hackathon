extends StaticBody2D

signal wall_broken
enum State { INTACT, CRACKED, BROKEN }
var state := State.INTACT

func _ready() -> void:
	add_to_group("breakable_wall")
	DimensionManager.dimension_changed.connect(_on_dimension_changed)
	_on_dimension_changed(DimensionManager.current_dimension)

func _on_dimension_changed(value: DimensionManager.Dimension) -> void:
	if state == State.BROKEN: return
	state = State.CRACKED if value == DimensionManager.Dimension.ALTERNATE else State.INTACT
	$Polygon2D.color = Color("c43c59") if state == State.CRACKED else Color("67718b")

func try_break(source: Node) -> bool:
	if state == State.BROKEN or not source.is_in_group("charging_monster"): return false
	state = State.BROKEN
	$Polygon2D.visible = false
	var wall_sprite := get_node_or_null("WallSprite") as Sprite2D
	if wall_sprite:
		wall_sprite.visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	wall_broken.emit()
	return true
