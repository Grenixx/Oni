extends Camera2D

func _ready():
	if is_multiplayer_authority():
		make_current()      # Active cette caméra pour le joueur local
