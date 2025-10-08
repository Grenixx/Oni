extends GPUParticles2D

@onready var player = get_node_or_null("/root/World/1")

func _process(delta):

	if player == null:
		player = get_node_or_null("/root/World/1")
		return

	# Position du joueur dans le monde
	var pos = player.global_position

	# Vitesse du joueur (selon ton node)
	var vel = Vector2.ZERO
	if "velocity" in player:
		vel = player.velocity 
	elif "linear_velocity" in player:
		vel = player.linear_velocity

	# Donne ces valeurs au shader
	process_material.set_shader_parameter("player_pos", pos)
	process_material.set_shader_parameter("player_vel", vel)
