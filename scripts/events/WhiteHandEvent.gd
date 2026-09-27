class_name WhiteHandEvent
extends CanvasLayer
## End-of-floor cutscene, modeled on Vampire Survivors' White Hand / Reaper.
## When GameState fires `white_hand_started`, the camera closes in on the
## player in three steps, then the reaper walks in from the left edge, waits,
## and steps toward the player until it touches them: an instant kill that
## counts as a win.
##
## The reaper lives on this CanvasLayer, not in the world. It chases the
## player's *screen* position, so no amount of running on the floor escapes it.

const REAPER_TEXTURE := preload("res://assets/sprites/boss/Ozge_Reaper.png")
const SFX_TENSION := preload("res://assets/audio/sfx/tension_hit.wav")
const SFX_STEP := preload("res://assets/audio/sfx/boss_step.wav")
const SFX_KILL := preload("res://assets/audio/sfx/insta_kill.wav")

const INTRO_DELAY := 1.5            ## Silence after the clock stops, before the first zoom.
const ZOOM_STEPS: Array[float] = [1.35, 1.7, 2.1]
const ZOOM_TWEEN := 0.35
const ZOOM_HOLD := 2.0              ## Pause after each zoom so the sound can ring out.
const REAPER_HEIGHT := 120.0        ## On-screen height in pixels.
const STEP_LENGTH := 42.0           ## Screen pixels covered per step.
const STEP_TIME := 0.5
const STEP_LIFT := 10.0             ## How high the sprite hops each step.
const STEP_TILT := 0.12             ## Radians the sprite rocks left/right each step.
const WAIT_AT_MARK := 3.0           ## Pause at the middle of the left half.
const KILL_DISTANCE := 26.0
const DEATH_HOLD := 1.6             ## Blood on screen before the results come up.
const MAX_STEPS := 200              ## Safety net; the reaper always arrives well before this.

var _player: Player = null
var _reaper: Sprite2D = null
var _step_parity: int = 1
var _foot_offset: float = 0.0  ## Sprite offset that puts its feet on the node origin.
var _vignette: ColorRect = null
var _flash: ColorRect = null
var _sfx: AudioStreamPlayer = null
var _step_sfx: AudioStreamPlayer = null


func _ready() -> void:
	layer = 5  ## Above the HUD, below the upgrade (30) and game over (10) menus.
	_build_nodes()
	EventBus.white_hand_started.connect(_on_white_hand_started)


func _build_nodes() -> void:
	_vignette = ColorRect.new()
	_vignette.color = Color(0, 0, 0, 0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_vignette)

	_reaper = Sprite2D.new()
	_reaper.texture = REAPER_TEXTURE
	_reaper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_foot_offset = -REAPER_TEXTURE.get_height() * 0.5
	_reaper.offset = Vector2(0, _foot_offset)  ## Pivot at the feet.
	var s := REAPER_HEIGHT / REAPER_TEXTURE.get_height()
	_reaper.scale = Vector2(s, s)
	_reaper.visible = false
	add_child(_reaper)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)

	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"SFX"
	add_child(_sfx)
	_step_sfx = AudioStreamPlayer.new()
	_step_sfx.bus = &"SFX"
	_step_sfx.volume_db = -4.0
	add_child(_step_sfx)


func _on_white_hand_started() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player == null:
		return
	_run()


func _run() -> void:
	_fade_out_music()
	_hide_hud()
	await _wait(INTRO_DELAY)

	for i in ZOOM_STEPS.size():
		_play(_sfx, SFX_TENSION)
		var zt := create_tween().set_parallel(true)
		zt.tween_property(_player.camera, "zoom", Vector2.ONE * ZOOM_STEPS[i], ZOOM_TWEEN) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		zt.tween_property(_vignette, "color:a", 0.18 * (i + 1), ZOOM_TWEEN)
		_player.add_shake(6.0)
		await _wait(ZOOM_HOLD)

	# Walk in from off-screen left to the middle of the left half.
	var view := get_viewport().get_visible_rect().size
	var mark := Vector2(view.x * 0.25, view.y * 0.5 + REAPER_HEIGHT * 0.5)
	_reaper.position = Vector2(-REAPER_HEIGHT, mark.y)
	_reaper.visible = true
	while _reaper.position.distance_to(mark) > 1.0:
		await _step_toward(mark)
	await _wait(WAIT_AT_MARK)

	# Close in on wherever the player is on screen right now.
	for i in MAX_STEPS:
		var target := _player_screen_feet()
		if _reaper.position.distance_to(target) <= KILL_DISTANCE:
			break
		await _step_toward(target)

	await _kill()


## One stride: slide forward while the sprite hops and rocks, thud on landing.
func _step_toward(target: Vector2) -> void:
	var to_target := target - _reaper.position
	var dist := to_target.length()
	var dest := target if dist <= STEP_LENGTH else _reaper.position + to_target / dist * STEP_LENGTH
	if absf(to_target.x) > 1.0:
		_reaper.flip_h = to_target.x < 0.0  ## Sprite is drawn facing right.
	_step_parity = -_step_parity

	var half := STEP_TIME * 0.5
	var lift := STEP_LIFT / _reaper.scale.y  ## offset is in texture pixels.
	var slide := create_tween()
	slide.tween_property(_reaper, "position", dest, STEP_TIME).set_trans(Tween.TRANS_SINE)
	var hop := create_tween()
	hop.tween_property(_reaper, "offset:y", _foot_offset - lift, half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.parallel().tween_property(_reaper, "rotation", STEP_TILT * _step_parity, half).set_trans(Tween.TRANS_SINE)
	hop.tween_property(_reaper, "offset:y", _foot_offset, half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hop.parallel().tween_property(_reaper, "rotation", 0.0, half).set_trans(Tween.TRANS_SINE)
	await slide.finished
	_play(_step_sfx, SFX_STEP)


func _kill() -> void:
	_player.freeze()
	_play(_sfx, SFX_KILL)
	_spawn_blood(_player.get_global_transform_with_canvas().origin)
	_player.visible = false
	_player.add_shake(12.0)
	var ft := create_tween()
	ft.tween_property(_flash, "color:a", 0.85, 0.05)
	ft.tween_property(_flash, "color:a", 0.0, 0.35)
	await _wait(DEATH_HOLD)

	var zt := create_tween().set_parallel(true)
	zt.tween_property(_player.camera, "zoom", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	zt.tween_property(_vignette, "color:a", 0.0, 0.6)
	await zt.finished
	await _wait(0.3)
	_player.insta_kill()


func _spawn_blood(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 90
	p.lifetime = 1.4
	p.direction = Vector2.UP
	p.spread = 80.0
	p.gravity = Vector2(0, 520)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 260.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color = Color(0.75, 0.03, 0.05)
	add_child(p)
	move_child(p, _reaper.get_index())  ## Blood behind the reaper, like the video.
	p.emitting = true


func _player_screen_feet() -> Vector2:
	return _player.get_global_transform_with_canvas().origin + Vector2(0, 16.0 * _player.camera.zoom.y)


func _hide_hud() -> void:
	var hud := get_parent().get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		create_tween().tween_property(hud, "offset:y", -160.0, 1.2).set_trans(Tween.TRANS_SINE)


func _fade_out_music() -> void:
	var t := MusicPlayer.create_tween()
	t.tween_property(MusicPlayer, "volume_db", -60.0, 1.2)
	t.tween_callback(MusicPlayer.stop)


func _play(player: AudioStreamPlayer, stream: AudioStream) -> void:
	player.stream = stream
	player.play()


## Pause-aware wait (the pause menu should freeze the cutscene too).
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout
