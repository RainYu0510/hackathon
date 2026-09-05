extends Area2D

func _ready() -> void:
	add_to_group("interactable")

func interact(player: PlayerBase) -> void:
	# The dog uses a wrist device and never wears the copyrighted cat goggles.
	if player.special_animation != "goggle" or player.has_goggle:
		return
	player.acquire_goggle()
	queue_free()
