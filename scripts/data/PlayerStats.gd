class_name PlayerStats
extends RefCounted
## Plain container for every number an upgrade can touch.
## Weapons read these multipliers instead of hardcoding values.

const BASE_MAX_HEALTH := 100.0
const BASE_MOVE_SPEED := 190.0
const BASE_PICKUP_RANGE := 72.0

var max_health_bonus: float = 0.0
var damage_mult: float = 1.0
var fire_rate_mult: float = 1.0
var move_speed_mult: float = 1.0
var area_mult: float = 1.0
var pickup_range_mult: float = 1.0
var xp_gain_mult: float = 1.0
var health_regen: float = 0.0
var armor: float = 0.0
var extra_projectiles: float = 0.0


func max_health() -> float:
	return BASE_MAX_HEALTH + max_health_bonus


func move_speed() -> float:
	return BASE_MOVE_SPEED * move_speed_mult


func pickup_range() -> float:
	return BASE_PICKUP_RANGE * pickup_range_mult


## Additive application; every upgrade in UpgradeDB is expressed as a delta.
func apply(stat: String, amount: float) -> void:
	if not stat in self:
		push_warning("PlayerStats: unknown stat '%s'" % stat)
		return
	set(stat, get(stat) + amount)
