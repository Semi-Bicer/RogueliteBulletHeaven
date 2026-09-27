class_name Enemy
extends CharacterBody2D

const DAMAGE_NUMBER_SCENE := preload("res://scenes/ui/DamageNumber.tscn")

## Swarm unit. Walks at the player (around walls, via the level's flow field)
## and damages on contact.
## All variants share this script; stats and sprite come from EnemySpawner.TYPES.
## Sprites are drawn facing right and flipped toward the direction of travel.

const KNOCKBACK_DECAY := 9.0
const HIT_FLASH := Color(2.5, 2.5, 2.5)  ## Overbright modulate washes the sprite white.

@onready var body_visual: Sprite2D = $Body
@onready var collision: CollisionShape2D = $CollisionShape2D

var max_health: float = 10.0
var health: float = 10.0
var speed: float = 55.0
var contact_damage: float = 6.0
var xp_value: int = 1
var is_boss: bool = false

var _player: Node2D = null
var _level: Node = null  ## Optional; without one, enemies walk in a straight line.
var _knockback: Vector2 = Vector2.ZERO
var _dying: bool = false


func _ready() -> void:
	add_to_group("enemies")
	_player = get_tree().get_first_node_in_group("player")
	_level = get_tree().get_first_node_in_group("level")
	EventBus.white_hand_started.connect(_on_white_hand_started)


## The 5-minute White Hand wipes the floor so only the reaper is left.
func _on_white_hand_started() -> void:
	if not _dying:
		_die()


## `data` is one entry of EnemySpawner.TYPES; `mult` is the time-based ramp.
func configure(data: Dictionary, mult: float) -> void:
	max_health = float(data["health"]) * mult
	health = max_health
	speed = float(data["speed"]) * minf(1.0 + (mult - 1.0) * 0.15, 1.6)
	contact_damage = float(data["damage"]) * (1.0 + (mult - 1.0) * 0.5)
	xp_value = int(data["xp"])
	is_boss = bool(data.get("boss", false))

	var radius := float(data["size"])
	var circle := CircleShape2D.new()
	circle.radius = radius
	collision.shape = circle
	body_visual.texture = data["sprite"]


func _physics_process(delta: float) -> void:
	if _dying:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	var dir := global_position.direction_to(_player.global_position)
	if _level != null:
		dir = _level.flow_direction(global_position, _player.global_position)
	var desired := dir * speed
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * 60.0 * delta)
	velocity = desired + _knockback
	move_and_slide()
	if not is_zero_approx(desired.x):
		body_visual.flip_h = desired.x < 0.0


func get_contact_damage() -> float:
	return contact_damage


func take_damage(amount: float) -> void:
	if _dying:
		return
	health -= amount
	EventBus.damage_dealt.emit(global_position, amount, false)
	
	# --- HASAR YAZISINI ÇIKART ---
	var dmg_popup = DAMAGE_NUMBER_SCENE.instantiate()
	dmg_popup.global_position = global_position + Vector2(0, -14)
	var parent_node := get_parent()
	if parent_node != null:
		parent_node.add_child(dmg_popup)
	else:
		get_tree().current_scene.add_child(dmg_popup)
	dmg_popup.setup(amount)
	# -----------------------------

	if _player != null:
		_knockback = (global_position - _player.global_position).normalized() * (60.0 if not is_boss else 12.0)
	_flash()
	if health <= 0.0:
		_die()


func _flash() -> void:
	body_visual.modulate = HIT_FLASH
	var tween := create_tween()
	tween.tween_property(body_visual, "modulate", Color.WHITE, 0.12)


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
