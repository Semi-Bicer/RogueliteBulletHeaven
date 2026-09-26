class_name Player
extends CharacterBody2D
## The survivor. Handles movement, health, weapon slots and upgrade application.
## Every attack is automatic: the player only ever steers.

const ARENA := Rect2(-3000, -3000, 6000, 6000)
const CONTACT_TICK := 0.45  ## Seconds between contact-damage ticks.
const IFRAME_FLASH := 0.12
const STARTING_WEAPON := "magic_missile"

@onready var weapon_root: Node2D = $Weapons
@onready var hurt_box: Area2D = $HurtBox
@onready var pickup_area: Area2D = $PickupArea
@onready var pickup_shape: CollisionShape2D = $PickupArea/CollisionShape2D
@onready var body_visual: AnimatedSprite2D = $Body
@onready var camera: Camera2D = $Camera2D

var stats := PlayerStats.new()
var health: float = 100.0
var alive: bool = true
var owned_upgrades: Dictionary = {}  ## upgrade id -> level
var facing: Vector2 = Vector2.RIGHT

var _contact_timer: float = 0.0
var _shake: float = 0.0


func _ready() -> void:
	add_to_group("player")
	health = stats.max_health()
	_refresh_pickup_radius()
	pickup_area.area_entered.connect(_on_pickup_area_entered)
	apply_upgrade(STARTING_WEAPON)
	EventBus.player_health_changed.emit(health, stats.max_health())


func _physics_process(delta: float) -> void:
	if not alive:
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		facing = input_dir.normalized()
	velocity = input_dir.normalized() * stats.move_speed()
	move_and_slide()
	global_position = global_position.clamp(ARENA.position, ARENA.end)
	_update_animation(input_dir)

	if stats.health_regen > 0.0 and health < stats.max_health():
		heal(stats.health_regen * delta, false)

	_tick_contact_damage(delta)
	_tick_shake(delta)


## Sprite sheet faces right; flip for leftward movement, keep last facing when idle.
func _update_animation(input_dir: Vector2) -> void:
	if input_dir == Vector2.ZERO:
		body_visual.play(&"idle")
		return
	body_visual.play(&"run")
	if not is_zero_approx(input_dir.x):
		body_visual.flip_h = input_dir.x < 0.0


func _tick_contact_damage(delta: float) -> void:
	_contact_timer -= delta
	if _contact_timer > 0.0:
		return
	var touching := hurt_box.get_overlapping_bodies()
	if touching.is_empty():
		return
	var worst: float = 0.0
	for body in touching:
		if body.has_method("get_contact_damage"):
			worst = maxf(worst, body.get_contact_damage())
	if worst > 0.0:
		_contact_timer = CONTACT_TICK
		take_damage(worst)


func _tick_shake(delta: float) -> void:
	if _shake <= 0.0:
		camera.offset = Vector2.ZERO
		return
	_shake = maxf(0.0, _shake - delta * 24.0)
	camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))


func add_shake(amount: float) -> void:
	_shake = minf(14.0, _shake + amount)


func take_damage(amount: float) -> void:
	if not alive:
		return
	var final := maxf(1.0, amount - stats.armor)
	health -= final
	add_shake(final * 0.35)
	_flash(Color(1, 0.45, 0.45))
	EventBus.player_health_changed.emit(maxf(health, 0.0), stats.max_health())
	if health <= 0.0:
		_die()


func heal(amount: float, flash: bool = true) -> void:
	if not alive:
		return
	health = minf(stats.max_health(), health + amount)
	if flash:
		_flash(Color(0.5, 1, 0.6))
	EventBus.player_health_changed.emit(health, stats.max_health())


func _die() -> void:
	alive = false
	velocity = Vector2.ZERO
	body_visual.stop()
	body_visual.modulate = Color(0.45, 0.45, 0.5)
	EventBus.player_died.emit()
	GameState.end_run(false)


func _flash(color: Color) -> void:
	body_visual.modulate = color
	var tween := create_tween()
	tween.tween_property(body_visual, "modulate", Color.WHITE, IFRAME_FLASH)


# --- Upgrades -----------------------------------------------------------

## Single entry point from an upgrade id to a weapon or a stat change.
func apply_upgrade(id: String) -> void:
	var data := UpgradeDB.get_upgrade(id)
	if data.is_empty():
		push_warning("Player: no upgrade registered for id '%s'" % id)
		return
	match String(data.get("kind", "")):
		"weapon":
			_apply_weapon_upgrade(data)
		"passive":
			stats.apply(String(data["stat"]), float(data["amount"]))
			_post_passive(String(data["stat"]), float(data["amount"]))
		"consumable":
			heal(30.0)
			return
	owned_upgrades[id] = int(owned_upgrades.get(id, 0)) + 1
	EventBus.upgrade_applied.emit(id, owned_upgrades[id])


func _apply_weapon_upgrade(data: Dictionary) -> void:
	var existing = get_weapon(String(data["id"]))
	if existing != null:
		existing.level_up()
		return
	var packed: PackedScene = load(String(data["scene"]))
	var weapon = packed.instantiate()
	weapon.weapon_id = String(data["id"])
	weapon_root.add_child(weapon)
	weapon.setup(self)


func _post_passive(stat: String, amount: float) -> void:
	match stat:
		"max_health_bonus":
			heal(amount, false)
		"pickup_range_mult":
			_refresh_pickup_radius()
	EventBus.player_health_changed.emit(health, stats.max_health())


func get_weapon(id: String):
	for w in weapon_root.get_children():
		if w.weapon_id == id:
			return w
	return null


func weapon_count() -> int:
	return weapon_root.get_child_count()


func _refresh_pickup_radius() -> void:
	var shape := pickup_shape.shape as CircleShape2D
	if shape != null:
		shape.radius = stats.pickup_range()


func _on_pickup_area_entered(area: Area2D) -> void:
	if area.has_method("attract_to"):
		area.attract_to(self)
