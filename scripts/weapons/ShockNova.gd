extends WeaponBase
## Periodic shockwave centred on the player. Stats follow docs/DESIGN.md §5.

const WAVE := preload("res://scripts/weapons/NovaWave.gd")

var damage: float = 14.0
var radius: float = 120.0


func _configure() -> void:
	damage = 14.0 + (level - 1) * 5.0
	radius = 120.0 + (level - 1) * 14.0
	base_cooldown = maxf(1.1, 2.6 - (level - 1) * 0.16)


func _fire() -> void:
	var parent := get_tree().get_first_node_in_group("projectile_parent")
	if parent == null:
		return
	var wave: Area2D = WAVE.new()
	wave.setup(damage_of(damage), area_of(radius))
	parent.add_child(wave)
	wave.global_position = player.global_position
	player.add_shake(2.5)
