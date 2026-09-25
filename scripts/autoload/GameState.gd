extends Node
## Owns the state of a single run: timer, level/XP curve, kill count.

const RUN_DURATION := 900.0  ## 15 minutes = victory.

var run_time: float = 0.0
var kills: int = 0
var level: int = 1
var xp: int = 0
var xp_to_next: int = 5
var running: bool = false
var victory: bool = false

func _process(delta: float) -> void:
	if not running:
		return
	run_time += delta
	EventBus.run_time_changed.emit(run_time)
	if run_time >= RUN_DURATION:
		end_run(true)


func start_run() -> void:
	run_time = 0.0
	kills = 0
	level = 1
	xp = 0
	xp_to_next = xp_for_level(1)
	running = true
	victory = false
	EventBus.run_started.emit()
	EventBus.kills_changed.emit(kills)
	EventBus.player_xp_changed.emit(xp, xp_to_next, level)
	EventBus.run_time_changed.emit(run_time)


func end_run(won: bool) -> void:
	if not running:
		return
	running = false
	victory = won
	EventBus.run_ended.emit(won)


## Classic survivor-like curve: cheap early levels, steep later ones.
func xp_for_level(lv: int) -> int:
	return int(5 + lv * 3 + pow(lv, 1.55))


func add_xp(amount: int) -> void:
	if not running:
		return
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = xp_for_level(level)
		EventBus.player_leveled_up.emit(level)
	EventBus.player_xp_changed.emit(xp, xp_to_next, level)


func add_kill() -> void:
	kills += 1
	EventBus.kills_changed.emit(kills)


## Difficulty ramp shared by the spawner and enemy stat scaling.
func difficulty() -> float:
	return 1.0 + (run_time / 60.0) * 0.28


func time_string() -> String:
	var total := int(run_time)
	return "%02d:%02d" % [total / 60, total % 60]
