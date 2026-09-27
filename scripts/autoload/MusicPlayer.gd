extends AudioStreamPlayer
## Plays the main theme for the whole session. Lives as an autoload so the
## music keeps going across scene changes (menu -> run -> restart).

const MAIN_THEME: AudioStreamOggVorbis = preload("res://assets/audio/music/main_theme.ogg")
const DEFAULT_VOLUME_DB := -8.0

func _ready() -> void:
	# Keep playing while the tree is paused (level-up screen, pause menu).
	process_mode = Node.PROCESS_MODE_ALWAYS
	bus = &"Music"
	volume_db = DEFAULT_VOLUME_DB
	play_theme(MAIN_THEME)
	# The White Hand cutscene fades the music out; bring it back on the next run.
	EventBus.run_started.connect(_on_run_started)


func _on_run_started() -> void:
	volume_db = DEFAULT_VOLUME_DB
	play_theme(MAIN_THEME)


func play_theme(theme: AudioStream) -> void:
	if stream == theme and playing:
		return
	if theme is AudioStreamOggVorbis:
		theme.loop = true
	stream = theme
	play()
