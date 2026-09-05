extends Node2D

@export var dimension := DimensionManager.Dimension.NORMAL

func _ready() -> void:
	add_to_group("dimension_normal" if dimension == DimensionManager.Dimension.NORMAL else "dimension_alternate")
	DimensionManager.dimension_changed.connect(_apply)
	_apply(DimensionManager.current_dimension)

func _apply(value: DimensionManager.Dimension) -> void:
	var enabled := value == dimension
	visible = enabled
	for child in find_children("*", "CollisionShape2D", true, false):
		child.set_deferred("disabled", not enabled)

