extends CanvasLayer

@onready var title_label: Label = $Control/CenterContainer/VBoxContainer/TitleLabel
@onready var score_label: Label = $Control/CenterContainer/VBoxContainer/ScoreLabel
@onready var time_label: Label = $Control/CenterContainer/VBoxContainer/TimeLabel
@onready var restart_button: Button = $Control/CenterContainer/VBoxContainer/RestartButton
@onready var main_menu_button: Button = $Control/CenterContainer/VBoxContainer/MainMenuButton

var total_kills: int = 0
var elapsed_seconds: float = 0.0

func _ready() -> void:
	hide()
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

	# EventBus sinyallerini dinle
	EventBus.kills_changed.connect(_on_kills_changed)
	EventBus.run_time_changed.connect(_on_time_changed)
	EventBus.player_died.connect(_on_player_died)
	EventBus.run_ended.connect(_on_run_ended)

func _on_kills_changed(kills: int) -> void:
	total_kills = kills

func _on_time_changed(seconds: float) -> void:
	elapsed_seconds = seconds

func _on_player_died() -> void:
	# 5 dakika = 300 saniye kontrolü
	if elapsed_seconds >= 300.0:
		show_game_over("ZAFER!", Color(1.0, 0.85, 0.2)) # Altın sarısı
	else:
		show_game_over("ÖLDÜNÜZ", Color(0.9, 0.2, 0.2)) # Kırmızı

func _on_run_ended(victory: bool) -> void:
	if victory or elapsed_seconds >= 300.0:
		show_game_over("ZAFER!", Color(1.0, 0.85, 0.2))
	else:
		show_game_over("YENİLGİ", Color(0.9, 0.2, 0.2))

func show_game_over(header_text: String, header_color: Color = Color.WHITE) -> void:
	title_label.text = header_text
	title_label.modulate = header_color

	# Süreyi 02:45 gibi formatla
	var mins: int = int(elapsed_seconds) / 60
	var secs: int = int(elapsed_seconds) % 60
	time_label.text = "Süre: %02d:%02d" % [mins, secs]
	score_label.text = "Öldürülen: %d" % total_kills

	show()
	get_tree().paused = true
	restart_button.grab_focus()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/StartMenu.tscn")

func _input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed:
		# 'K' tuşu: Erken ölüm testi (ÖLDÜNÜZ ekranı)
		if event.keycode == KEY_K:
			elapsed_seconds = 140.0
			EventBus.player_died.emit()
		
		# 'L' tuşu: 5. dakikadan sonraki ölüm testi (ZAFER! ekranı)
		elif event.keycode == KEY_L:
			elapsed_seconds = 315.0
			EventBus.player_died.emit()
