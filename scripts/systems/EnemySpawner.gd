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
const BATCH_SPREAD := 128.0  ## Max distance from a batch's anchor inside a level.

const TYPES := {
	"slime": {"health": 11.0, "speed": 52.0, "damage": 7.0, "xp": 1, "size": 13.0,
		"sprite": preload("res://assets/sprites/enemies/slime.png")},
	"bat": {"health": 7.0, "speed": 96.0, "damage": 5.0, "xp": 1, "size": 10.0,
		"sprite": preload("res://assets/sprites/enemies/bat.png")},
	"brute": {"health": 46.0, "speed": 40.0, "damage": 14.0, "xp": 4, "size": 20.0,
		"sprite": preload("res://assets/sprites/enemies/brute.png")},
	"husk": {"health": 120.0, "speed": 34.0, "damage": 20.0, "xp": 9, "size": 27.0,
		"sprite": preload("res://assets/sprites/enemies/husk.png")},
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
	# Cluster the batch so swarms read as a wave, not a ring. Inside a level
	# the wave gathers around one walkable anchor; in open space, one arc.
	var level := get_tree().get_first_node_in_group("level")
	var origin := _player.global_position
	var anchor := Vector2.INF
	if level != null:
		anchor = level.random_spawn_point(origin, SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
	var arc_center := randf_range(0.0, TAU)
	for i in count:
		var pos: Vector2
		if level != null:
			pos = level.random_spawn_point(origin, SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX, anchor, BATCH_SPREAD)
		else:
			var angle := arc_center + randf_range(-0.6, 0.6)
			pos = origin + Vector2.from_angle(angle) * randf_range(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
		_spawn(pool[randi() % pool.size()], pos)


func _spawn(type_name: String, pos: Vector2) -> void:
	var data: Dictionary = TYPES[type_name]
	var enemy := ENEMY.instantiate()
	add_child(enemy)
	enemy.global_position = pos
	enemy.configure(data, GameState.difficulty())


func _cull_distant() -> void:
	var origin := _player.global_position
	var limit := DESPAWN_RADIUS * DESPAWN_RADIUS
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_squared_to(origin) > limit:
			e.queue_free()
