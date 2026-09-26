extends Node2D
## Run root. Starts the run, turns enemy deaths into XP gems, drives the
## level-up picker, and reloads the scene on request.

const GEM := preload("res://scenes/pickups/XPGem.tscn")

@onready var spawner: Node2D = $EnemySpawner
@onready var player: Player = $Entities/Player
@onready var picker = $LevelUpPicker

var _pending_level_ups: int = 0


func _ready() -> void:
	randomize()
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_leveled_up.connect(_on_leveled_up)
	EventBus.run_ended.connect(_on_run_ended)
	picker.choice_selected.connect(_on_choice_selected)
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


# --- Level-up picker -------------------------------------------------------

func _on_leveled_up(_new_level: int) -> void:
	_pending_level_ups += 1
	# A single big gem can grant several levels in one add_xp() call, which
	# fires this signal several times in a row before the picker has had a
	# chance to show itself. Only the first one should actually open it.
	if not picker.visible:
		_open_next_picker()


func _open_next_picker() -> void:
	if _pending_level_ups <= 0:
		return
	get_tree().paused = true
	var choices := UpgradeDB.roll(player.owned_upgrades, 3)
	picker.open_picker(choices)


func _on_choice_selected(id: String) -> void:
	player.apply_upgrade(id)
	_pending_level_ups -= 1
	get_tree().paused = false
	if _pending_level_ups > 0:
		_open_next_picker.call_deferred()


func _on_run_ended(_victory: bool) -> void:
	_pending_level_ups = 0
	get_tree().paused = false
	picker.hide()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
