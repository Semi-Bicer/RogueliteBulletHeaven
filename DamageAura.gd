extends Area2D
# DamageAura.gd
# Add as a child node of your Player scene: an Area2D named "DamageAura"
# with a CollisionShape2D (a Circle works well) inside it. Starts invisible
# and harmless — it only does anything once the player has ranked it up at
# least once.

@export var base_radius: float = 40.0
@export var radius_per_rank: float = 15.0
@export var base_damage_per_tick: float = 3.0
@export var damage_per_rank: float = 2.0
@export var tick_interval: float = 0.5

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _tick_timer: Timer = Timer.new()

var rank: int = 0
var _damage_per_tick: float = 0.0


func _ready() -> void:
	_tick_timer.wait_time = tick_interval
	_tick_timer.one_shot = false
	add_child(_tick_timer)
	_tick_timer.timeout.connect(_on_tick)
	_tick_timer.start()

	set_rank(0)  # start inactive


## Call this whenever the player picks the "aura" special (rank goes up by 1 each time).
func set_rank(new_rank: int) -> void:
	rank = new_rank
	visible = rank > 0
	set_deferred("monitoring", rank > 0)

	var radius = base_radius + radius_per_rank * rank
	if _collision_shape.shape is CircleShape2D:
		_collision_shape.shape.radius = radius

	_damage_per_tick = base_damage_per_tick + damage_per_rank * rank


func _on_tick() -> void:
	if rank <= 0:
		return

	for body in get_overlapping_bodies():
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(_damage_per_tick)
