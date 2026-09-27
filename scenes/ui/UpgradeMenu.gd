extends CanvasLayer

@onready var cards_container: HBoxContainer = $Control/CenterContainer/VBoxContainer/CardsContainer
const CARD_SCENE := preload("res://scenes/ui/UpgradeCard.tscn")

## Level-ups not yet spent. One big gem can grant several levels in a single
## add_xp() call; each is offered in turn instead of the extras being lost.
var _pending: int = 0

func _ready() -> void:
	hide()
	EventBus.player_leveled_up.connect(_on_player_leveled_up)
	EventBus.run_ended.connect(_on_run_ended)

func _on_player_leveled_up(_new_level: int) -> void:
	_pending += 1
	if not visible:
		open_upgrade_menu()

func _on_run_ended(_victory: bool) -> void:
	# The end screen owns the pause state from here; just stand down.
	_pending = 0
	hide()

func open_upgrade_menu() -> void:
	# Önceki kartları temizle
	for child in cards_container.get_children():
		child.queue_free()

	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var choices := UpgradeDB.roll(player.owned_upgrades, 3)

	var first_button: Button = null

	for item in choices:
		var card = CARD_SCENE.instantiate()
		cards_container.add_child(card)
		var tag := "YENİ" if item["is_new"] else "LV %d" % item["next_level"]
		card.setup(item["id"], "%s  (%s)" % [item["name"], tag], item["desc"])
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

	_pending -= 1
	if _pending > 0:
		open_upgrade_menu.call_deferred()
		return
	hide()
	get_tree().paused = false
