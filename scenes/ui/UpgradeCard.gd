extends PanelContainer

signal selected(upgrade_id: String)

@onready var icon_rect: TextureRect = $MarginContainer/VBoxContainer/Icon
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var desc_label: Label = $MarginContainer/VBoxContainer/DescLabel
@onready var select_button: Button = $MarginContainer/VBoxContainer/SelectButton

var current_upgrade_id: String = ""

func _ready() -> void:
	select_button.pressed.connect(_on_select_pressed)

func setup(id: String, title: String, description: String, icon: Texture2D = null) -> void:
	current_upgrade_id = id
	title_label.text = title
	desc_label.text = description
	
	if icon:
		icon_rect.texture = icon
		icon_rect.visible = true
	else:
		icon_rect.visible = false

func _on_select_pressed() -> void:
	selected.emit(current_upgrade_id)
