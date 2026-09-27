extends Control
## Volume page shared by the start menu and the pause menu. The owner shows it
## with open() and gets `closed` back when the player leaves (button or ESC).

signal closed

@onready var master_slider: HSlider = $Panel/Margin/VBox/MasterRow/Slider
@onready var music_slider: HSlider = $Panel/Margin/VBox/MusicRow/Slider
@onready var sfx_slider: HSlider = $Panel/Margin/VBox/SfxRow/Slider
@onready var master_value: Label = $Panel/Margin/VBox/MasterRow/Value
@onready var music_value: Label = $Panel/Margin/VBox/MusicRow/Value
@onready var sfx_value: Label = $Panel/Margin/VBox/SfxRow/Value
@onready var mute_check: CheckBox = $Panel/Margin/VBox/MuteCheck
@onready var back_button: Button = $Panel/Margin/VBox/BackButton

var _rows: Dictionary = {}  ## bus -> [slider, value label]


func _ready() -> void:
	hide()
	_rows = {
		&"Master": [master_slider, master_value],
		&"Music": [music_slider, music_value],
		&"SFX": [sfx_slider, sfx_value],
	}
	for bus in _rows:
		var slider: HSlider = _rows[bus][0]
		slider.value_changed.connect(_on_slider_changed.bind(bus))
	mute_check.toggled.connect(func(on: bool) -> void: AudioSettings.set_muted(on))
	back_button.pressed.connect(close)
	AudioSettings.changed.connect(_refresh)


func open() -> void:
	_refresh()
	show()
	music_slider.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_slider_changed(value: float, bus: StringName) -> void:
	AudioSettings.set_volume(bus, value / 100.0)


func _refresh() -> void:
	for bus in _rows:
		var slider: HSlider = _rows[bus][0]
		var label: Label = _rows[bus][1]
		var pct := roundi(AudioSettings.get_volume(bus) * 100.0)
		slider.set_value_no_signal(pct)
		label.text = "%d%%" % pct
	mute_check.set_pressed_no_signal(AudioSettings.muted)
