extends CanvasLayer

@onready var resume_button: Button = $Control/CenterContainer/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Control/CenterContainer/VBoxContainer/RestartButton
@onready var quit_button: Button = $Control/CenterContainer/VBoxContainer/QuitButton
@onready var sound_button: Button = $Control/CenterContainer/VBoxContainer/SoundButton
@onready var menu_box: CenterContainer = $Control/CenterContainer
@onready var sound_settings: Control = $Control/SoundSettings

func _ready() -> void:
	hide()
	resume_button.pressed.connect(resume_game)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	sound_button.pressed.connect(_open_sound_settings)
	sound_settings.closed.connect(_on_sound_settings_closed)

func _unhandled_input(event: InputEvent) -> void:
	# ESC tuşuna veya pause aksiyonuna basıldığında
	if event.is_action_pressed("ui_cancel"):
		if sound_settings.visible:
			return  # SoundSettings closes itself on ESC.
		if visible:
			resume_game()
		else:
			pause_game()

func pause_game() -> void:
	show()
	get_tree().paused = true
	resume_button.grab_focus()

func resume_game() -> void:
	sound_settings.hide()
	menu_box.show()
	hide()
	get_tree().paused = false

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/StartMenu.tscn")

func _open_sound_settings() -> void:
	menu_box.hide()
	sound_settings.open()

func _on_sound_settings_closed() -> void:
	menu_box.show()
	sound_button.grab_focus()
