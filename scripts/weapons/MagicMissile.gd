extends WeaponBase
## Starting weapon. Fires homing bolts at the nearest enemies; with nothing
## alive it fires along the player's facing. Stats follow docs/DESIGN.md §5.

const PROJECTILE := preload("res://scenes/weapons/Projectile.tscn")
const SPEED := 430.0
const SPREAD := 0.35  ## Radians of jitter for bolts that share a target.

var damage: float = 10.0
var bolts: int = 1
var pierce: int = 0


func _configure() -> void:
	damage = 10.0 + (level - 1) * 4.0
	bolts = 1 + (level - 1) / 2
	pierce = (level - 1) / 3
	base_cooldown = maxf(0.28, 0.85 - (level - 1) * 0.05)


func _fire() -> void:
	var parent := get_tree().get_first_node_in_group("projectile_parent")
	if parent == null:
		return
	var count := bolts + int(player.stats.extra_projectiles)
	var targets := nearest_enemies(count)
	var origin: Vector2 = player.global_position
	for i in count:
		var dir: Vector2
		if targets.is_empty():
			dir = player.facing.rotated(randf_range(-SPREAD, SPREAD) if i > 0 else 0.0)
		elif i < targets.size():
			dir = origin.direction_to(targets[i].global_position)
		else:
			dir = origin.direction_to(targets[-1].global_position).rotated(randf_range(-SPREAD, SPREAD))
		var bolt := PROJECTILE.instantiate()
		bolt.setup(dir * SPEED, damage_of(damage), pierce)
		parent.add_child(bolt)
		bolt.global_position = origin
