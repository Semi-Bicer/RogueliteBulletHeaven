extends CanvasLayer

@onready var cards_container: HBoxContainer = $Control/CenterContainer/VBoxContainer/CardsContainer
const CARD_SCENE := preload("res://scenes/ui/UpgradeCard.tscn")

# Arkadaşın UpgradeDB'yi tam doldurana kadar kullanılacak test verisi
var mock_pool: Array[Dictionary] = [
	{"id": "speed_boost", "title": "Çeviklik", "desc": "Hareket hızını %15 artırır."},
	{"id": "health_up", "title": "Dayanıklılık", "desc": "Maksimum canı +25 artırır ve can doldurur."},
	{"id": "pickup_range", "title": "Mıknatıs", "desc": "Toplama alanını %30 genişletir."},
	{"id": "rapid_fire", "title": "Seri Atış", "desc": "Saldırı hızını %20 artırır."},
	{"id": "damage_boost", "title": "Kuvvet", "desc": "Tüm silahlara ek hasar ekler."}
]

func _ready() -> void:
	hide()
	EventBus.player_leveled_up.connect(_on_player_leveled_up)

func _on_player_leveled_up(_new_level: int) -> void:
	open_upgrade_menu()

func open_upgrade_menu() -> void:
	# Önceki kartları temizle
	for child in cards_container.get_children():
		child.queue_free()

	# 3 rastgele seçenek seç
	var pool := mock_pool.duplicate()
	pool.shuffle()
	var choices := pool.slice(0, 3)

	var first_button: Button = null

	for item in choices:
		var card = CARD_SCENE.instantiate()
		cards_container.add_child(card)
		card.setup(item["id"], item["title"], item["desc"])
		card.selected.connect(_on_card_selected)
		
		if first_button == null:
			first_button = card.select_button

	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if first_button:
		first_button.grab_focus()

func _on_card_selected(id: String) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("apply_upgrade"):
		player.apply_upgrade(id)

	hide()
	get_tree().paused = false
