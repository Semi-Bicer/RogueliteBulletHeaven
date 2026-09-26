extends CanvasLayer

@onready var xp_bar: ProgressBar = $Control/TopMargin/XPBar
@onready var level_label: Label = $Control/StatsMargin/HBoxContainer/LevelLabel
@onready var timer_label: Label = $Control/StatsMargin/HBoxContainer/TimerLabel
@onready var kills_label: Label = $Control/StatsMargin/HBoxContainer/KillsLabel

func _ready() -> void:
	EventBus.player_xp_changed.connect(_on_xp_changed)
	EventBus.run_time_changed.connect(_on_time_changed)
	EventBus.kills_changed.connect(_on_kills_changed)
	
	# Başlangıç değerleri (GameState hazırsa)
	xp_bar.max_value = GameState.xp_to_next
	xp_bar.value = GameState.xp
	level_label.text = "LVL %d" % GameState.level
	timer_label.text = GameState.time_string()
	kills_label.text = "%d Kills" % GameState.kills

func _on_xp_changed(current: int, needed: int, level: int) -> void:
	xp_bar.max_value = needed
	xp_bar.value = current
	level_label.text = "LVL %d" % level

func _on_time_changed(_seconds: float) -> void:
	timer_label.text = GameState.time_string()

func _on_kills_changed(kills: int) -> void:
	kills_label.text = "%d Kills" % kills
	
