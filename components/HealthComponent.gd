class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal died
@export var max_health := 5
var health := 5

func _ready() -> void:
	health = max_health

func damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		died.emit()

func restore() -> void:
	health = max_health
	health_changed.emit(health, max_health)

