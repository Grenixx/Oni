extends Node2D


func _on_hurt_box_area_entered(area: Area2D) -> void:
	if area.get_parent().has_method("player"):
		print(area)
