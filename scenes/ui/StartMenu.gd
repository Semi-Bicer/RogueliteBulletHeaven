extends CanvasLayer

@onready var start_button: Button = $Control/CenterContainer/VBoxContainer/StartButton
@onready var quit_button: Button = $Control/CenterContainer/VBoxContainer/QuitButton
@onready var sound_button: Button = $Control/CenterContainer/VBoxContainer/SoundButton
@onready var menu_box: CenterContainer = $Control/CenterContainer
@onready var sound_settings: Control = $Control/SoundSettings

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	sound_button.pressed.connect(_open_sound_settings)
	sound_settings.closed.connect(_on_sound_settings_closed)
	
	# Klavye / Gamepad ile hemen seçilebilsin:
	start_button.grab_focus()

func _on_start_pressed() -> void:
	# Oyunun ana sahnesine geçiş:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _open_sound_settings() -> void:
	menu_box.hide()
	sound_settings.open()

func _on_sound_settings_closed() -> void:
	menu_box.show()
	sound_button.grab_focus()
