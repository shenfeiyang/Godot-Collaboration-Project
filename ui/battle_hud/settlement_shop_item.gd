extends Button
class_name SettlementShopItem

signal item_pressed(item_index: int)

@onready var name_label: Label = $Margin/Content/TopRow/NameLabel
@onready var price_label: Label = $Margin/Content/TopRow/PriceLabel
@onready var description_label: Label = $Margin/Content/DescriptionLabel
@onready var state_label: Label = $Margin/Content/StateLabel
@onready var selection_frame: ColorRect = $SelectionFrame
@onready var glow_frame: PanelContainer = $GlowFrame

var _item_index: int = -1
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

func bind_item(item_index: int, item_data: Dictionary) -> void:
	_item_index = item_index
	_payload = item_data.duplicate(true)
	if name_label != null:
		name_label.text = String(item_data.get("name", "未命名商品"))
	if price_label != null:
		price_label.text = String(item_data.get("price_text", "0 金币"))
	if description_label != null:
		description_label.text = String(item_data.get("description", "暂无说明。"))
	if state_label != null:
		state_label.text = String(item_data.get("state_text", "可购买"))
		state_label.visible = not state_label.text.is_empty()

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
	scale = Vector2.ONE * (1.01 if _is_selected else (1.005 if _is_hovered else 1.0))

func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_visual_state()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_visual_state()

func _on_pressed() -> void:
	item_pressed.emit(_item_index)
