extends Area2D
## One Shock Nova blast. Its circle grows from 8 px to `max_radius` over
## GROW_TIME (cubic ease-out), damaging each enemy it touches exactly once,
## then fades out and frees itself. Stays where it was cast.

const START_RADIUS := 8.0
const GROW_TIME := 0.32
const FADE_TIME := 0.18
const COLOR := Color(0.7, 0.6, 1.0)

var damage: float = 14.0
var max_radius: float = 120.0
var radius: float = START_RADIUS:
	set(value):
		radius = value
		if _shape != null:
			_shape.radius = value
		queue_redraw()

var _shape := CircleShape2D.new()
var _hit: Dictionary = {}  ## instance id -> true


func setup(dmg: float, r: float) -> void:
	damage = dmg
	max_radius = r


func _ready() -> void:
	z_index = 4
	collision_layer = 4
	collision_mask = 2
	monitorable = false
	var col := CollisionShape2D.new()
	col.shape = _shape
	add_child(col)
	radius = START_RADIUS
	var tween := create_tween()
	tween.tween_property(self, "radius", max_radius, GROW_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(set_deferred.bind("monitoring", false))
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)


func _physics_process(_delta: float) -> void:
	if not monitoring:
		return
	for body in get_overlapping_bodies():
		var id := body.get_instance_id()
		if _hit.has(id) or not body.has_method("take_damage"):
			continue
		_hit[id] = true
		body.take_damage(damage)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(COLOR, 0.12))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(COLOR, 0.85), 3.0)
