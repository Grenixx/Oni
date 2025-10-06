extends CharacterBody2D

func _ready() -> void:
	print("d")
	var local_id = multiplayer.get_unique_id()
	print("Mon ID :", multiplayer.get_peers())
