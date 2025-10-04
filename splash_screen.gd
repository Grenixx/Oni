extends Control

@export var load_Scene : PackedScene
@export var in_time : float = 0.5
@export var fade_in_time : float = 1.5
@export var pause_time : float = 1.5
@export var fade_out_time : float = 1.5
@export var out_time : float = 0.5
@export var splash_screen : TextureRect

func _ready() -> void:
	fade()

func fade() -> void:
	splash_screen.modulate.a = 0.0
	var tween = create_tween()

	tween.tween_interval(in_time)
	tween.tween_property(splash_screen, "modulate:a", 1.0, fade_in_time)
	tween.tween_interval(pause_time)
	tween.tween_property(splash_screen, "modulate:a", 0.0, fade_out_time)
	tween.tween_interval(out_time)

	tween.finished.connect(_on_fade_complete)

func _on_fade_complete() -> void:
	if load_Scene:
		get_tree().change_scene_to_packed(load_Scene)
