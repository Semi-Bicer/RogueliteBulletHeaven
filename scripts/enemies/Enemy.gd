class_name Enemy
extends CharacterBody2D
## Swarm unit. Walks straight at the player and damages on contact.
## All variants share this script; stats come from EnemySpawner.TYPES.

const KNOCKBACK_DECAY := 9.0

@onready var body_visual: Polygon2D = $Body
@onready var collision: CollisionShape2D = $CollisionShape2D

var max_health: float = 10.0
var health: float = 10.0
var speed: float = 55.0
var contact_damage: float = 6.0
var xp_value: int = 1
var is_boss: bool = false
var base_color: Color = Color(0.85, 0.35, 0.42)

var _player: Node2D = null
var _knockback: Vector2 = Vector2.ZERO
var _dying: bool = false


func _ready() -> void:
	add_to_group("enemies")
	_player = get_tree().get_first_node_in_group("player")


## `data` is one entry of EnemySpawner.TYPES; `mult` is the time-based ramp.
func configure(data: Dictionary, mult: float) -> void:
	max_health = float(data["health"]) * mult
	health = max_health
	speed = float(data["speed"]) * minf(1.0 + (mult - 1.0) * 0.15, 1.6)
	contact_damage = float(data["damage"]) * (1.0 + (mult - 1.0) * 0.5)
	xp_value = int(data["xp"])
	is_boss = bool(data.get("boss", false))
	base_color = data["color"]

	var radius := float(data["size"])
	var circle := CircleShape2D.new()
	circle.radius = radius
	collision.shape = circle
	body_visual.scale = Vector2.ONE * (radius / 14.0)
	body_visual.color = base_color


func _physics_process(delta: float) -> void:
	if _dying:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	var to_player := _player.global_position - global_position
	var desired := to_player.normalized() * speed
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * 60.0 * delta)
	velocity = desired + _knockback
	move_and_slide()


func get_contact_damage() -> float:
	return contact_damage


func take_damage(amount: float) -> void:
	if _dying:
		return
	health -= amount
	EventBus.damage_dealt.emit(global_position, amount, false)
	if _player != null:
		_knockback = (global_position - _player.global_position).normalized() * (60.0 if not is_boss else 12.0)
	_flash()
	if health <= 0.0:
		_die()


func _flash() -> void:
	body_visual.color = Color(1, 1, 1)
	var tween := create_tween()
	tween.tween_property(body_visual, "color", base_color, 0.12)


func _die() -> void:
	_dying = true
	remove_from_group("enemies")
	set_physics_process(false)
	GameState.add_kill()
	EventBus.enemy_died.emit(global_position, xp_value)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(body_visual, "scale", body_visual.scale * 1.6, 0.14)
	tween.tween_property(self, "modulate:a", 0.0, 0.14)
	tween.chain().tween_callback(queue_free)
