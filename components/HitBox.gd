class_name HitBox
extends Area2D

@export var damage := 1
@export var team := "neutral"
var attack_id := 0
var already_hit: Dictionary = {}

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	monitoring = false

func begin_attack() -> void:
	attack_id += 1
	already_hit.clear()
	monitoring = true

func end_attack() -> void:
	monitoring = false

func _on_area_entered(area: Area2D) -> void:
	if area is HurtBox and area.team != team and not already_hit.has(area):
		already_hit[area] = attack_id
		area.receive_hit(damage, owner)

