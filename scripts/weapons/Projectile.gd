class_name Projectile
extends Area2D
## Player bolt. Flies straight, optionally homes on the nearest enemy in range,
## and damages each enemy at most once so pierce cannot double-dip.

const LIFETIME := 2.4
const HOMING_RANGE := 260.0
const HOMING_STRENGTH := 3.0  ## Slerp weight per second.

@export var homing: bool = true

var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var pierce_left: int = 0

var _life: float = LIFETIME
var _hit: Dictionary = {}  ## instance id -> true


func setup(vel: Vector2, dmg: float, pierce: int) -> void:
	velocity = vel
	damage = dmg
	pierce_left = pierce
	rotation = vel.angle()


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	var target := _nearest_target() if homing else null
	if target != null:
		var speed := velocity.length()
		var want := global_position.direction_to(target.global_position) * speed
		velocity = velocity.slerp(want, minf(1.0, HOMING_STRENGTH * delta))
	global_position += velocity * delta
	rotation = velocity.angle()


func _nearest_target() -> Node2D:
	var best: Node2D = null
	var best_d := HOMING_RANGE * HOMING_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if _hit.has(e.get_instance_id()):
			continue
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("take_damage") or _hit.has(body.get_instance_id()):
		return
	_hit[body.get_instance_id()] = true
	body.take_damage(damage)
	if pierce_left <= 0:
		queue_free.call_deferred()
		set_deferred("monitoring", false)
	else:
		pierce_left -= 1
