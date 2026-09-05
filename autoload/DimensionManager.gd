extends Node

signal dimension_changed(new_dimension: Dimension)
enum Dimension { NORMAL, ALTERNATE }
var current_dimension: Dimension = Dimension.NORMAL

func set_dimension(value: Dimension) -> void:
	if current_dimension == value:
		return
	current_dimension = value
	dimension_changed.emit(current_dimension)

func toggle() -> void:
	set_dimension(Dimension.ALTERNATE if current_dimension == Dimension.NORMAL else Dimension.NORMAL)

func reset() -> void:
	current_dimension = Dimension.NORMAL
	dimension_changed.emit(current_dimension)

func label() -> String:
	return "NORMAL" if current_dimension == Dimension.NORMAL else "ALTERNATE"

