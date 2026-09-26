extends WeaponBase
## Piercing fireball. Flies straight (no homing) at the nearest enemy so it can
## punch through a line of them. Hits 2 enemies at level 1, +1 per level.

const PROJECTILE := preload("res://scenes/weapons/FireBallProjectile.tscn")
const SPEED := 360.0
const SPREAD := 0.25  ## Radians between extra fireballs from Split Shot.

var damage: float = 18.0
var hits: int = 2


func _configure() -> void:
	damage = 18.0 + (level - 1) * 5.0
	hits = 2 + (level - 1)
	base_cooldown = maxf(0.9, 1.6 - (level - 1) * 0.08)


func _fire() -> void:
	var parent := get_tree().get_first_node_in_group("projectile_parent")
	if parent == null:
		return
	var origin: Vector2 = player.global_position
	var targets := nearest_enemies(1)
	var aim: Vector2 = player.facing if targets.is_empty() \
		else origin.direction_to(targets[0].global_position)
	var count := 1 + int(player.stats.extra_projectiles)
	for i in count:
		# Fan extra shots evenly around the aim line: 0, +s, -s, +2s, ...
		var offset := SPREAD * ceilf(i / 2.0) * (1.0 if i % 2 == 1 else -1.0)
		var ball := PROJECTILE.instantiate()
		ball.setup(aim.rotated(offset) * SPEED, damage_of(damage), hits - 1)
		parent.add_child(ball)
		ball.global_position = origin
