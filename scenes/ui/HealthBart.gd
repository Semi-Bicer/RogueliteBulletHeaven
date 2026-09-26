extends ProgressBar

func _ready() -> void:
	# EventBus'taki can sinyalini dinle
	EventBus.player_health_changed.connect(_on_health_changed)

func _on_health_changed(current: float, maximum: float) -> void:
	max_value = maximum
	value = current
	
	# İsteğe bağlı: Can tam doluyken gizlensin, hasar alınca görünsün istersen:
	# visible = current < maximum
