extends Area2D
## Experience drop. Idle until the player's pickup radius touches it,
## then it flies in and is consumed.

const COLLECT_DISTANCE := 14.0
const ACCEL := 1400.0
const MAX_SPEED := 720.0

var value: int = 1

var _target: Node2D = null
var _speed: float = 60.0
var _collected: bool = false


func setup(xp: int) -> void:
	value = xp
	var visual := $Body as Polygon2D
	if xp >= 25:
		visual.color = Color(0.98, 0.55, 0.30)
		visual.scale = Vector2.ONE * 1.6
	elif xp >= 5:
		visual.color = Color(0.72, 0.53, 0.98)
		visual.scale = Vector2.ONE * 1.25


func attract_to(player: Node2D) -> void:
	_target = player


func _physics_process(delta: float) -> void:
	if _collected or _target == null or not is_instance_valid(_target):
		return
	var to_target := _target.global_position - global_position
	var distance := to_target.length()
	_speed = minf(MAX_SPEED, _speed + ACCEL * delta)
	var step := _speed * delta
	# Collect when this frame's step would carry us past the player, so a
	# long frame can never make the gem oscillate around them.
	if distance <= COLLECT_DISTANCE or distance <= step:
		_collect()
		return
	global_position += to_target / distance * step


func _collect() -> void:
	_collected = true
	var gain := value
	if "stats" in _target:
		gain = int(round(float(value) * _target.stats.xp_gain_mult))
	GameState.add_xp(maxi(1, gain))
	queue_free()
