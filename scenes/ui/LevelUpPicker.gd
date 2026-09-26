extends CanvasLayer
## Level-up card picker. Main owns the pause state and the pending-level
## queue; this node only builds cards from whatever `UpgradeDB.roll()`
## result it's given and reports back which one was chosen.

signal choice_selected(id: String)

const CARD_SIZE := Vector2(228, 200)

@onready var card_container: HBoxContainer = $Control/CenterContainer/VBoxContainer/CardContainer


func _ready() -> void:
	hide()


## `choices` is the Array returned by UpgradeDB.roll() — each entry has
## id, name, desc, kind, color, current_level, next_level, is_new.
func open_picker(choices: Array) -> void:
	_clear_cards()
	for choice in choices:
		card_container.add_child(_build_card(choice))
	show()
	# Wait a frame so the buttons exist before we try to focus one —
	# makes the screen keyboard/controller playable, per the design doc.
	await get_tree().process_frame
	if card_container.get_child_count() > 0:
		card_container.get_child(0).grab_focus()


func _clear_cards() -> void:
	for c in card_container.get_children():
		c.queue_free()


func _build_card(choice: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = CARD_SIZE
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.focus_mode = Control.FOCUS_ALL

	var tag := "NEW" if bool(choice.get("is_new", false)) else "LV %d" % int(choice.get("next_level", 1))
	btn.text = "%s\n\n%s\n\n%s" % [
		String(choice.get("name", "")),
		String(choice.get("desc", "")),
		tag,
	]

	var tint = choice.get("color", Color.WHITE)
	if tint is Color:
		btn.modulate = tint

	btn.pressed.connect(_on_card_pressed.bind(String(choice["id"])))
	return btn


func _on_card_pressed(id: String) -> void:
	hide()
	choice_selected.emit(id)
