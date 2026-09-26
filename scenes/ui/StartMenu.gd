extends CanvasLayer

@onready var start_button: Button = $Control/CenterContainer/VBoxContainer/StartButton
@onready var quit_button: Button = $Control/CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Klavye / Gamepad ile hemen seçilebilsin:
	start_button.grab_focus()

func _on_start_pressed() -> void:
	# Oyunun ana sahnesine geçiş:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
