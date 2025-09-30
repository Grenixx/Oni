extends Node2D

var peer = ENetMultiplayerPeer.new()
const PORT = 8081

func _on_host_pressed() -> void:
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer # Replace with function body.
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(del_player)
	add_player() #si le server a un joueur
	$CanvasLayer.hide()
	
func _on_join_pressed() -> void:
	peer.create_client("127.0.0.1", PORT)
	multiplayer.multiplayer_peer = peer
	$CanvasLayer.hide()

@onready var player_scene = preload("res://Objects/Player.tscn")
func add_player(id = 1):
	var player = player_scene.instantiate()
	player.name = str(id)
	# player.global_transform.origin = Vector3(0, 0, 0)  # ou un spawn point

	call_deferred("add_child", player)

#func exit_game(id):
#	multiplayer.peer_disconnected.connect(del_player)
#	del_player(id)  #si le server a un joueur

@rpc("any_peer","call_local")
func del_player(id):
	get_node(str(id)).queue_free()
