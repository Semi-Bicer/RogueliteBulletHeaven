extends Area2D
# Bullet.gd
# Attach to your bullet/projectile scene (an Area2D with a CollisionShape2D
# and a Sprite2D, moving forward each frame).
#
# Ricochet and piercing are just two counters: how many more screen-edge
# bounces, and how many more enemies, this bullet can survive before it
# disappears. Both start at 0 (normal bullet) unless the player has ranked
# them up.

@export var speed: float = 500.0
@export var damage: float = 10.0

var direction: Vector2 = Vector2.RIGHT
var bounces_remaining: int = 0   # from the player's "bounce" special rank
var pierce_remaining: int = 0    # from the player's "pierce" special rank


## Call this right after spawning the bullet.
## player_specials: the same Dictionary PlayerProgression.gd fills in, e.g. {"bounce": 2, "pierce": 1}.
func setup(start_direction: Vector2, bullet_damage: float, player_specials: Dictionary) -> void:
	direction = start_direction.normalized()
	damage = bullet_damage
	bounces_remaining = player_specials.get("bounce", 0)
	pierce_remaining = player_specials.get("pierce", 0)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_check_screen_bounce()


func _check_screen_bounce() -> void:
	var screen_rect = get_viewport_rect()
	var bounced = false

	if position.x <= screen_rect.position.x or position.x >= screen_rect.end.x:
		direction.x = -direction.x
		bounced = true
	if position.y <= screen_rect.position.y or position.y >= screen_rect.end.y:
		direction.y = -direction.y
		bounced = true

	if bounced:
		if bounces_remaining > 0:
			bounces_remaining -= 1
			# clamp back inside the screen so it doesn't get stuck bouncing at the edge
			position = position.clamp(screen_rect.position, screen_rect.end)
		else:
			queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return

	if body.has_method("take_damage"):
		body.take_damage(damage)

	if pierce_remaining > 0:
		pierce_remaining -= 1
	else:
		queue_free()
