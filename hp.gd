# health.gd
extends Node

# signaux
signal hp_changed(current : int, max : int)
signal died()

@export var max_hp: int = 100
var hp: int

# invuln possible
@export var invulnerability_time: float = 0.0
var _invuln_timer: float = 0.0

func _ready():
	hp = max_hp

func _process(delta):
	if _invuln_timer > 0.0:
		_invuln_timer = max(0.0, _invuln_timer - delta)

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	if _invuln_timer > 0.0:
		return # invuln frames
	hp = clamp(hp - amount, 0, max_hp)
	emit_signal("hp_changed", hp, max_hp)
	_invuln_timer = invulnerability_time
	if hp == 0:
		emit_signal("died")

func heal(amount: int) -> void:
	if amount <= 0:
		return
	hp = clamp(hp + amount, 0, max_hp)
	emit_signal("hp_changed", hp, max_hp)

func set_max_hp(new_max: int) -> void:
	max_hp = max(1, new_max)
	hp = clamp(hp, 0, max_hp)
	emit_signal("hp_changed", hp, max_hp)

func is_dead() -> bool:
	return hp <= 0
