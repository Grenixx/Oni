extends Control

@export var game_scene_packed = preload("res://Scene/World.tscn")

func _on_host_pressed():
	# Change vers la scène du jeu
	NetworkSettings.mode = "host"
	get_tree().change_scene_to_packed(game_scene_packed)
	# On peut passer un mode "host" via une variable globale ou un singleton

func _on_join_pressed():
	NetworkSettings.mode = "join"
	NetworkSettings.ip = $CanvasLayer/HBoxContainer/BoxContainer/LineEdit.text
	get_tree().change_scene_to_packed(game_scene_packed)
	# On peut stocker l'IP à rejoindre via singleton ou autoload

func _on_host_play_pressed() -> void:
	NetworkSettings.mode = "host+join"
	get_tree().change_scene_to_packed(game_scene_packed)
	# Même principe : indiquer que c'est host+join
