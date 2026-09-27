extends Node2D

@onready var label: Label = $Label

func setup(amount: float, is_critical: bool = false) -> void:
	# Tam sayı ise virgülleri at (15.0 yerine 15)
	if is_equal_approx(amount, roundf(amount)):
		label.text = str(int(amount))
	else:
		label.text = "%.1f" % amount

	# Kritik vuruş veya yüksek hasar kontrolü
	if is_critical or amount >= 25.0:
		label.modulate = Color(1.0, 0.3, 0.2) # Turuncu/Kırmızı
		scale = Vector2(1.3, 1.3)
	else:
		label.modulate = Color(1.0, 0.9, 0.4) # Sarımsı

	# Rastgele hafif sağa/sola sapma payı (üst üste binmesinler)
	var random_x := randf_range(-14.0, 14.0)
	var target_pos := position + Vector2(random_x, -35.0)

	# Animasyon: Yukarı süzül ve şeffaflaşıp silin
	var tween := create_tween().set_parallel(true)
	
	# Yukarı doğru süzülme
	tween.tween_property(self, "position", target_pos, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Hafif büyüme ve küçülme (pop efekti)
	tween.tween_property(self, "scale", scale * 1.15, 0.15).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(self, "scale", Vector2.ZERO, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	
	# Saydamlaşma
	tween.tween_property(self, "modulate:a", 0.0, 0.55).set_ease(Tween.EASE_IN)
	
	# Animasyon bitince sahneden tamamen sil
	tween.chain().tween_callback(queue_free)
