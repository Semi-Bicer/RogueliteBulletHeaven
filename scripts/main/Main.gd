extends Node2D
## Run root. Starts the run, turns enemy deaths into XP gems, and reloads the
## scene on request.
##
## Presentation (HUD, level-up picker, end-of-run screen) is deliberately absent:
## see docs/DESIGN.md section 8 for the spec it should be built against.

const GEM := preload("res://scenes/pickups/XPGem.tscn")

@onready var spawner: Node2D = $EnemySpawner
@onready var player: Player = $Entities/Player


func _ready() -> void:
	randomize()
	EventBus.enemy_died.connect(_on_enemy_died)
	GameState.start_run()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_run") and not GameState.running:
		_restart()


# Deferred: `enemy_died` fires from inside a physics callback, where adding a
# node with a collision shape to the tree is illegal.
func _on_enemy_died(pos: Vector2, xp_value: int) -> void:
	var gem := GEM.instantiate()
	gem.position = pos
	gem.setup(xp_value)
	spawner.add_child.call_deferred(gem)


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
