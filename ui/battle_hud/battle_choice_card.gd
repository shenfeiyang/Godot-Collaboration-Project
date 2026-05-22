extends Button
class_name BattleChoiceCard

signal card_pressed(card_index: int)

@onready var tag_label: Label = $Margin/Content/TagLabel
@onready var icon_panel: PanelContainer = $Margin/Content/IconPanel
@onready var icon_texture: TextureRect = $Margin/Content/IconPanel/IconCenter/IconTexture
@onready var title_label: Label = $Margin/Content/TitleLabel
@onready var description_label: Label = $Margin/Content/DescriptionLabel
@onready var selection_frame: ColorRect = $SelectionFrame
@onready var glow_frame: PanelContainer = $GlowFrame
@onready var card_backdrop: PanelContainer = $CardBackdrop

var _card_index: int = -1
var _payload: Dictionary = {}
var _is_selected: bool = false
var _is_hovered: bool = false

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	_update_visual_state()

func bind_card(card_index: int, card_data: Dictionary) -> void:
	_card_index = card_index
	_payload = card_data.duplicate(true)
	if tag_label != null:
		tag_label.text = String(card_data.get("tag", "候选项"))
		tag_label.visible = not tag_label.text.is_empty()
	if title_label != null:
		title_label.text = String(card_data.get("title", "未命名选项"))
	if description_label != null:
		description_label.text = String(card_data.get("description", "暂无说明。"))
	var icon_texture_value: Texture2D = card_data.get("icon", null) as Texture2D
	if icon_texture != null:
		icon_texture.texture = icon_texture_value
	if icon_panel != null:
		icon_panel.visible = icon_texture_value != null

func set_selected(is_selected: bool) -> void:
	_is_selected = is_selected
	_update_visual_state()

func get_payload() -> Dictionary:
	return _payload.duplicate(true)

func _update_visual_state() -> void:
	if selection_frame != null:
		selection_frame.visible = _is_selected
	if glow_frame != null:
		glow_frame.visible = _is_hovered or _is_selected
	var target_scale := Vector2.ONE
	if _is_selected:
		target_scale = Vector2.ONE * 1.02
	elif _is_hovered:
		target_scale = Vector2.ONE * 1.01
	scale = target_scale
	if card_backdrop != null:
		card_backdrop.self_modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_visual_state()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_visual_state()

func _on_pressed() -> void:
	card_pressed.emit(_card_index)
