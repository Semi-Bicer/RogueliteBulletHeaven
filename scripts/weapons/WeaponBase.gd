class_name WeaponBase
extends Node2D
## Shared skeleton for every weapon. Weapons never read input: they run on a
## cooldown that is scaled by the player's fire-rate stat, then call `_fire()`.

var weapon_id: String = ""
var level: int = 1
var player = null

var base_cooldown: float = 1.0
var _cooldown_left: float = 0.15


func setup(p) -> void:
	player = p
	_configure()


func _process(delta: float) -> void:
	if player == null or not player.alive or not GameState.running:
		return
	_cooldown_left -= delta * player.stats.fire_rate_mult
	if _cooldown_left <= 0.0:
		_cooldown_left += maxf(0.05, base_cooldown)
		_fire()


func level_up() -> void:
	level += 1
	_configure()


## Recalculate stats from `level`. Called on spawn and on every level up.
func _configure() -> void:
	pass


func _fire() -> void:
	pass


func damage_of(base: float) -> float:
	return base * player.stats.damage_mult


func area_of(base: float) -> float:
	return base * player.stats.area_mult


## Enemies sorted by distance to the player, closest first.
func nearest_enemies(count: int) -> Array:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return []
	var origin: Vector2 = player.global_position
	enemies.sort_custom(func(a, b):
		return a.global_position.distance_squared_to(origin) \
			< b.global_position.distance_squared_to(origin))
	return enemies.slice(0, mini(count, enemies.size()))
