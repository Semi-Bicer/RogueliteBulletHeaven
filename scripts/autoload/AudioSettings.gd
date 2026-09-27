extends Node
## Volume for the Master / Music / SFX buses, saved to user://settings.cfg.
## Also owns the global mute hotkey (`toggle_mute`, M), which works in every
## scene and while the game is paused.

signal changed

const SAVE_PATH := "user://settings.cfg"
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX"]
const DEFAULTS := {&"Master": 0.8, &"Music": 0.5, &"SFX": 0.8}

var volumes: Dictionary = DEFAULTS.duplicate()  ## bus name -> linear 0..1
var muted: bool = false

var _toast: Label = null
var _toast_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_apply_all()
	_build_toast()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mute"):
		set_muted(not muted)
		get_viewport().set_input_as_handled()


func get_volume(bus: StringName) -> float:
	return float(volumes.get(bus, 1.0))


func set_volume(bus: StringName, linear: float) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	_apply(bus)
	_save()
	changed.emit()


func set_muted(value: bool) -> void:
	muted = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), muted)
	_save()
	changed.emit()
	_show_toast("Ses kapalı (M)" if muted else "Ses açık (M)")


func _apply_all() -> void:
	for bus in BUSES:
		_apply(bus)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), muted)


func _apply(bus: StringName) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		push_warning("AudioSettings: bus '%s' missing from default_bus_layout.tres" % bus)
		return
	var linear := get_volume(bus)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	# Slider at 0 means silent, not just very quiet.
	if bus != &"Master":
		AudioServer.set_bus_mute(idx, linear <= 0.0)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for bus in BUSES:
		volumes[bus] = float(cfg.get_value("audio", String(bus), DEFAULTS[bus]))
	muted = bool(cfg.get_value("audio", "muted", false))


func _save() -> void:
	var cfg := ConfigFile.new()
	for bus in BUSES:
		cfg.set_value("audio", String(bus), volumes[bus])
	cfg.set_value("audio", "muted", muted)
	cfg.save(SAVE_PATH)


## Small corner notice so the mute key gives feedback in every scene.
func _build_toast() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	_toast = Label.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_toast.position += Vector2(-170, 12)
	_toast.custom_minimum_size = Vector2(160, 0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 4)
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_toast)


func _show_toast(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
