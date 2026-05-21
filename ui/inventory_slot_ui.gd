extends Control
class_name InventorySlotUI

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")
const DEFAULT_ITEM_ICON_ATLAS = preload("res://assets/texture/all_icon.png")
const RARITY_COLORS = {
	SHARED_ENUMS.ItemRarity.WHITE: Color(0.92, 0.92, 0.92, 1.0),
	SHARED_ENUMS.ItemRarity.GREEN: Color(0.42, 0.9, 0.5, 1.0),
	SHARED_ENUMS.ItemRarity.BLUE: Color(0.36, 0.65, 1.0, 1.0),
	SHARED_ENUMS.ItemRarity.PURPLE: Color(0.84, 0.45, 1.0, 1.0),
	SHARED_ENUMS.ItemRarity.ORANGE: Color(1.0, 0.66, 0.26, 1.0),
	SHARED_ENUMS.ItemRarity.RED: Color(1.0, 0.35, 0.35, 1.0),
	SHARED_ENUMS.ItemRarity.GOLD: Color(1.0, 0.84, 0.2, 1.0),
}

signal left_clicked(slot_index: int)
signal right_clicked(slot_index: int)

@export var slot_index: int = -1

@onready var background_rect: PanelContainer = $Background
@onready var quality_color_rect: ColorRect = $QualityColor
@onready var icon_rect: TextureRect = $Margin/Icon
@onready var slot_label: Label = $Label
@onready var count_label: Label = $CountLabel
@onready var touch_button: Button = $TouchButton

var _slot_data: InventorySlotData = null
var _is_selected: bool = false
var _label_text: String = ""
var _default_item_icon: AtlasTexture = _create_default_item_icon()

func _ready() -> void:
	if touch_button != null:
		touch_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_view()

func bind_slot_data(new_slot_data: InventorySlotData) -> void:
	_slot_data = new_slot_data
	_refresh_view()

func set_selected(value: bool) -> void:
	_is_selected = value
	_refresh_view()

func set_label_text(value: String) -> void:
	_label_text = value
	_refresh_view()

func get_slot_data() -> InventorySlotData:
	return _slot_data

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			left_clicked.emit(slot_index)
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			right_clicked.emit(slot_index)
			accept_event()
			return

func _refresh_view() -> void:
	if background_rect == null or quality_color_rect == null or icon_rect == null or count_label == null or slot_label == null:
		return
	var is_empty_slot: bool = _slot_data == null or _slot_data.is_empty()
	var should_show_slot_label: bool = is_empty_slot and not _label_text.is_empty()
	background_rect.modulate = Color(1.18, 1.08, 0.82, 1.0) if _is_selected else Color(1.0, 1.0, 1.0, 1.0)
	quality_color_rect.visible = not is_empty_slot and _slot_data.item_definition != null
	quality_color_rect.color = _get_rarity_color(_slot_data.item_definition.rarity) if quality_color_rect.visible else Color(1, 1, 1, 1)
	if should_show_slot_label:
		icon_rect.texture = null
		icon_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		icon_rect.texture = _default_item_icon if is_empty_slot else (_slot_data.item_definition.icon if _slot_data.item_definition != null and _slot_data.item_definition.icon != null else _default_item_icon)
		icon_rect.modulate = Color(0.78, 0.78, 0.78, 0.55) if is_empty_slot else Color(1.0, 1.0, 1.0, 1.0)
	count_label.visible = not is_empty_slot and _slot_data.quantity > 1
	count_label.text = str(_slot_data.quantity)
	slot_label.visible = should_show_slot_label
	slot_label.text = _label_text
	slot_label.modulate = Color(1.0, 0.95, 0.72, 1.0)

# 默认占位图标取自 all_icon 图集左上角第一格，避免缺图时显示整张图集。
func _create_default_item_icon() -> AtlasTexture:
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = DEFAULT_ITEM_ICON_ATLAS
	atlas_texture.region = Rect2(0, 0, 16, 16)
	return atlas_texture

func _get_rarity_color(rarity: int) -> Color:
	return RARITY_COLORS.get(rarity, Color(0.92, 0.92, 0.92, 1.0))
