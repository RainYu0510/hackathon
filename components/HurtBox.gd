class_name HurtBox
extends Area2D

signal hurt(damage: int, source: Node)
@export var team := "neutral"
var invulnerable := false

func receive_hit(damage: int, source: Node) -> void:
	if not invulnerable:
		hurt.emit(damage, source)

