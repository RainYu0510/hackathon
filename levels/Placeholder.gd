extends Node2D

func _ready() -> void:
	var label:=Label.new()
	label.text="LEVEL DESIGN TBD"
	label.position=Vector2(450,320)
	label.add_theme_font_size_override("font_size",42)
	add_child(label)

