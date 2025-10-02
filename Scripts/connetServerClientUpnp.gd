extends Node2D

var peer = ENetMultiplayerPeer.new()
const PORT = 8081

func _ready():
	var upnp = UPNP.new()
	var discover_result = upnp.discover()
	
	if discover_result == UPNP.UPNP_RESULT_SUCCESS:
		if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
			# Ouvre les ports UDP et TCP pour ton serveur
			var map_result_udp = upnp.add_port_mapping(PORT, PORT, "godot_udp", "UDP", 0)
			var map_result_tcp = upnp.add_port_mapping(PORT, PORT, "godot_tcp", "TCP", 0)

			# Vérifie si ça a marché
			if map_result_udp != UPNP.UPNP_RESULT_SUCCESS:
				push_error("Erreur mapping UDP")
			if map_result_tcp != UPNP.UPNP_RESULT_SUCCESS:
				push_error("Erreur mapping TCP")

			# Récupère l'IP publique
			var external_ip = upnp.query_external_address()
			$CanvasLayer/BoxContainer/Label.text = external_ip
			if external_ip != "":
				print("✅ IP publique du serveur :", external_ip, " sur le port ", PORT)
			else:
				push_error("Impossible de récupérer l'IP publique")
		else:
			push_error("Pas de passerelle UPNP valide trouvée.")
	else:
		push_error("Découverte UPNP échouée.")

func _on_host_pressed() -> void:
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(del_player)
	$CanvasLayer.hide()

func _on_join_pressed() -> void:
	if $CanvasLayer/BoxContainer/LineEdit.text :
		peer.create_client($CanvasLayer/BoxContainer/LineEdit.text, PORT)
	else:
		peer.create_client("127.0.0.1", PORT)
	#peer.create_client("127.0.0.1", PORT)
	multiplayer.multiplayer_peer = peer
	$CanvasLayer.hide()
	

func _on_host_play_pressed() -> void:
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(del_player)
	add_player() # si le serveur a déjà un joueur
	$CanvasLayer.hide()

@onready var player_scene = preload("res://Objects/Player.tscn")
func add_player(id = 1):
	var player = player_scene.instantiate()
	player.name = str(id)
	call_deferred("add_child", player)

@rpc("any_peer","call_local")
func del_player(id):
	get_node(str(id)).queue_free()
