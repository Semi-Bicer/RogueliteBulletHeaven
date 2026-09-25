extends Node2D
## Director for the survival loop. Spawns swarms in a ring outside the camera,
## swapping in tougher archetypes as the run clock advances. Also culls enemies
## that wander far behind the player.
##
## The Warden boss was removed on purpose; docs/DESIGN.md section 6 has its
## stats and the every-five-minutes cadence it should return with.

const ENEMY := preload("res://scenes/enemies/Enemy.tscn")

const SPAWN_RADIUS_MIN := 620.0
const SPAWN_RADIUS_MAX := 780.0
const DESPAWN_RADIUS := 1600.0
const MAX_ALIVE := 320

const TYPES := {
	"slime": {"health": 11.0, "speed": 52.0, "damage": 7.0, "xp": 1, "size": 13.0,
		"color": Color(0.84, 0.36, 0.44)},
	"bat": {"health": 7.0, "speed": 96.0, "damage": 5.0, "xp": 1, "size": 10.0,
		"color": Color(0.58, 0.44, 0.86)},
	"brute": {"health": 46.0, "speed": 40.0, "damage": 14.0, "xp": 4, "size": 20.0,
		"color": Color(0.90, 0.56, 0.26)},
	"husk": {"health": 120.0, "speed": 34.0, "damage": 20.0, "xp": 9, "size": 27.0,
		"color": Color(0.45, 0.72, 0.52)},
}

## Each phase: from `time` seconds on, spawn `batch` enemies every `every`
## seconds, picked from `pool`.
const PHASES := [
	{"time": 0.0,   "every": 1.30, "batch": 2, "pool": ["slime"]},
	{"time": 60.0,  "every": 1.15, "batch": 3, "pool": ["slime", "bat"]},
	{"time": 150.0, "every": 1.00, "batch": 4, "pool": ["slime", "bat", "bat"]},
	{"time": 270.0, "every": 0.90, "batch": 5, "pool": ["slime", "bat", "brute"]},
	{"time": 420.0, "every": 0.80, "batch": 6, "pool": ["bat", "brute", "husk"]},
	{"time": 600.0, "every": 0.70, "batch": 7, "pool": ["bat", "brute", "husk", "husk"]},
	{"time": 780.0, "every": 0.55, "batch": 9, "pool": ["brute", "husk", "husk"]},
]

var _spawn_timer: float = 0.0
var _cull_timer: float = 0.0
var _player: Node2D = null


func _ready() -> void:
	add_to_group("projectile_parent")


func _process(delta: float) -> void:
	if not GameState.running:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return

	var phase := _current_phase()
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = float(phase["every"])
		_spawn_batch(phase)

	_cull_timer -= delta
	if _cull_timer <= 0.0:
		_cull_timer = 2.0
		_cull_distant()


func _current_phase() -> Dictionary:
	var chosen: Dictionary = PHASES[0]
	for p in PHASES:
		if GameState.run_time >= float(p["time"]):
			chosen = p
	return chosen


func _spawn_batch(phase: Dictionary) -> void:
	var alive := get_tree().get_nodes_in_group("enemies").size()
	if alive >= MAX_ALIVE:
		return
	var pool: Array = phase["pool"]
	var count: int = mini(int(phase["batch"]), MAX_ALIVE - alive)
	# Cluster the batch in one arc so swarms read as a wave, not a ring.
	var arc_center := randf_range(0.0, TAU)
	for i in count:
		var angle := arc_center + randf_range(-0.6, 0.6)
		_spawn(pool[randi() % pool.size()], angle)


func _spawn(type_name: String, angle: float) -> void:
	var data: Dictionary = TYPES[type_name]
	var enemy := ENEMY.instantiate()
	var radius := randf_range(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
	add_child(enemy)
	enemy.global_position = _player.global_position + Vector2.from_angle(angle) * radius
	enemy.configure(data, GameState.difficulty())


func _cull_distant() -> void:
	var origin := _player.global_position
	var limit := DESPAWN_RADIUS * DESPAWN_RADIUS
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_squared_to(origin) > limit:
			e.queue_free()
