class_name WeaponBase
extends Node2D
## Shared skeleton for every weapon. Weapons never read input: they run on a
## cooldown that is scaled by the player's fire-rate stat, then call `_fire()`.

var weapon_id: String = ""
var level: int = 1
var player = null

var base_cooldown: float = 1.0
var _cooldown_left: float = 0.15
var _sfx: AudioStreamPlayer = null


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


## Plays one of `streams` on the SFX bus with a little pitch jitter so rapid
## fire doesn't sound like a machine. `polyphony` caps overlapping copies.
## The player is built on first use; a weapon always passes the same streams.
func play_sfx(streams: Array, volume_db: float = 0.0, polyphony: int = 3, pitch_jitter: float = 0.08) -> void:
	if streams.is_empty():
		return
	if _sfx == null:
		# A randomizer (not swapping `stream`) so overlapping shots don't cut each other off.
		var pool := AudioStreamRandomizer.new()
		for st in streams:
			pool.add_stream(-1, st)
		pool.random_pitch = 1.0 + pitch_jitter
		_sfx = AudioStreamPlayer.new()
		_sfx.stream = pool
		_sfx.bus = &"SFX"
		_sfx.volume_db = volume_db
		_sfx.max_polyphony = polyphony
		add_child(_sfx)
	_sfx.play()


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
