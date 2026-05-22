extends Control
class_name SettlementShopPanel

const SETTLEMENT_SHOP_ITEM_SCENE = preload("res://ui/battle_hud/settlement_shop_item.tscn")

signal purchase_requested(mode: StringName, item_index: int, item_data: Dictionary)
signal refresh_requested(mode: StringName)
signal continue_requested(mode: StringName, selected_item_index: int, selected_item_data: Dictionary)
signal closed

@onready var overlay: ColorRect = $Overlay
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/Content/Header/TitleBlock/TitleLabel
@onready var subtitle_label: Label = $Panel/Margin/Content/Header/TitleBlock/SubtitleLabel
@onready var currency_label: Label = $Panel/Margin/Content/Header/MetaBlock/CurrencyLabel
@onready var wave_label: Label = $Panel/Margin/Content/Header/MetaBlock/WaveLabel
@onready var close_button: Button = $Panel/Margin/Content/Header/CloseButton
@onready var summary_panel: PanelContainer = $Panel/Margin/Content/Body/LeftColumn/SummaryPanel
@onready var summary_label: Label = $Panel/Margin/Content/Body/LeftColumn/SummaryPanel/SummaryMargin/SummaryLabel
@onready var status_panel: PanelContainer = $Panel/Margin/Content/Body/LeftColumn/StatusPanel
@onready var status_label: Label = $Panel/Margin/Content/Body/LeftColumn/StatusPanel/StatusMargin/StatusLabel
@onready var details_panel: PanelContainer = $Panel/Margin/Content/Body/RightColumn/DetailsPanel
@onready var item_name_label: Label = $Panel/Margin/Content/Body/RightColumn/DetailsPanel/DetailsMargin/DetailsVBox/ItemNameLabel
@onready var item_price_label: Label = $Panel/Margin/Content/Body/RightColumn/DetailsPanel/DetailsMargin/DetailsVBox/ItemPriceLabel
@onready var item_description_label: Label = $Panel/Margin/Content/Body/RightColumn/DetailsPanel/DetailsMargin/DetailsVBox/ItemDescriptionLabel
@onready var item_state_label: Label = $Panel/Margin/Content/Body/RightColumn/DetailsPanel/DetailsMargin/DetailsVBox/ItemStateLabel
@onready var items_panel: PanelContainer = $Panel/Margin/Content/Body/RightColumn/ItemsPanel
@onready var items_list: VBoxContainer = $Panel/Margin/Content/Body/RightColumn/ItemsPanel/ItemsMargin/Scroll/ItemsList
@onready var footer_label: Label = $Panel/Margin/Content/FooterPanel/FooterMargin/FooterVBox/FooterLabel
@onready var leave_button: Button = $Panel/Margin/Content/FooterPanel/FooterMargin/FooterVBox/ActionsRow/LeaveButton
@onready var refresh_button: Button = $Panel/Margin/Content/FooterPanel/FooterMargin/FooterVBox/ActionsRow/RefreshButton
@onready var purchase_button: Button = $Panel/Margin/Content/FooterPanel/FooterMargin/FooterVBox/ActionsRow/PurchaseButton
@onready var continue_button: Button = $Panel/Margin/Content/FooterPanel/FooterMargin/FooterVBox/ActionsRow/ContinueButton

var _mode: StringName = &"summary_shop"
var _allow_close: bool = true
var _shop_items: Array[SettlementShopItem] = []
var _shop_entries: Array[Dictionary] = []
var _selected_index: int = -1

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	if close_button != null and not close_button.pressed.is_connected(hide_panel):
		close_button.pressed.connect(hide_panel)
	if overlay != null and not overlay.gui_input.is_connected(_on_overlay_gui_input):
		overlay.gui_input.connect(_on_overlay_gui_input)
	if leave_button != null and not leave_button.pressed.is_connected(_on_leave_button_pressed):
		leave_button.pressed.connect(_on_leave_button_pressed)
	if refresh_button != null and not refresh_button.pressed.is_connected(_on_refresh_button_pressed):
		refresh_button.pressed.connect(_on_refresh_button_pressed)
	if purchase_button != null and not purchase_button.pressed.is_connected(_on_purchase_button_pressed):
		purchase_button.pressed.connect(_on_purchase_button_pressed)
	if continue_button != null and not continue_button.pressed.is_connected(_on_continue_button_pressed):
		continue_button.pressed.connect(_on_continue_button_pressed)

func show_shop(shop_context: Dictionary) -> void:
	_mode = StringName(String(shop_context.get("mode", "summary_shop")))
	_allow_close = bool(shop_context.get("allow_close", true))
	title_label.text = String(shop_context.get("title", "战斗结算"))
	subtitle_label.text = String(shop_context.get("subtitle", "请选择你的后续行动。"))
	currency_label.text = String(shop_context.get("currency_text", "金币 0"))
	wave_label.text = String(shop_context.get("wave_text", "第 1 波"))
	summary_label.text = String(shop_context.get("summary_text", ""))
	status_label.text = String(shop_context.get("status_text", "请选择一个商品查看详情。"))
	footer_label.text = String(shop_context.get("footer_hint", "选择商品后可购买，或直接继续。"))
	close_button.visible = _allow_close
	summary_panel.visible = not summary_label.text.is_empty()
	status_panel.visible = not status_label.text.is_empty()
	_rebuild_shop_items(shop_context.get("items", []))
	var default_index := int(shop_context.get("selected_index", 0))
	if _shop_items.is_empty():
		_update_selection(-1)
	else:
		default_index = clamp(default_index, 0, _shop_items.size() - 1)
		_update_selection(default_index)
	_apply_mode_layout(shop_context)
	visible = true
	move_to_front()

func hide_panel() -> void:
	if not _allow_close:
		return
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") and _allow_close:
		hide_panel()
		get_viewport().set_input_as_handled()

func _on_overlay_gui_input(event: InputEvent) -> void:
	if not visible or not _allow_close:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_panel()
		accept_event()

func _rebuild_shop_items(item_entries: Variant) -> void:
	for child in items_list.get_children():
		child.queue_free()
	_shop_items.clear()
	_shop_entries.clear()
	var entries: Array = []
	if item_entries is Array:
		entries = item_entries
	for index in range(entries.size()):
		var item_data_variant: Variant = entries[index]
		if not item_data_variant is Dictionary:
			continue
		var item_data: Dictionary = (item_data_variant as Dictionary).duplicate(true)
		_shop_entries.append(item_data)
		var shop_item := SETTLEMENT_SHOP_ITEM_SCENE.instantiate() as SettlementShopItem
		if shop_item == null:
			continue
		items_list.add_child(shop_item)
		shop_item.bind_item(index, item_data)
		if not shop_item.item_pressed.is_connected(_on_shop_item_pressed):
			shop_item.item_pressed.connect(_on_shop_item_pressed)
		_shop_items.append(shop_item)

func _apply_mode_layout(shop_context: Dictionary) -> void:
	var show_summary: bool = bool(shop_context.get("show_summary", _mode != &"shop_focus"))
	var show_details: bool = bool(shop_context.get("show_details", true))
	var show_refresh: bool = bool(shop_context.get("show_refresh", _mode == &"shop_focus"))
	var show_purchase: bool = bool(shop_context.get("show_purchase", true))
	var show_continue: bool = bool(shop_context.get("show_continue", true))
	var show_leave: bool = bool(shop_context.get("show_leave", true))
	summary_panel.visible = summary_panel.visible and show_summary
	details_panel.visible = show_details
	refresh_button.visible = show_refresh
	purchase_button.visible = show_purchase
	continue_button.visible = show_continue
	leave_button.visible = show_leave

func _update_selection(item_index: int) -> void:
	_selected_index = item_index
	for index in range(_shop_items.size()):
		_shop_items[index].set_selected(index == item_index)
	if item_index < 0 or item_index >= _shop_entries.size():
		item_name_label.text = "未选择商品"
		item_price_label.text = ""
		item_description_label.text = "请选择左侧商品查看详情。"
		item_state_label.text = ""
		purchase_button.disabled = true
		return
	var item_data: Dictionary = _shop_entries[item_index]
	item_name_label.text = String(item_data.get("name", "未命名商品"))
	item_price_label.text = String(item_data.get("price_text", "0 金币"))
	item_description_label.text = String(item_data.get("detail_text", item_data.get("description", "暂无说明。")))
	item_state_label.text = String(item_data.get("state_text", "可购买"))
	purchase_button.disabled = bool(item_data.get("purchase_disabled", false))

func _get_selected_item_data() -> Dictionary:
	if _selected_index < 0 or _selected_index >= _shop_entries.size():
		return {}
	return _shop_entries[_selected_index].duplicate(true)

func _on_shop_item_pressed(item_index: int) -> void:
	_update_selection(item_index)

func _on_leave_button_pressed() -> void:
	if not _allow_close:
		return
	hide_panel()

func _on_refresh_button_pressed() -> void:
	refresh_requested.emit(_mode)

func _on_purchase_button_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _shop_entries.size():
		return
	purchase_requested.emit(_mode, _selected_index, _get_selected_item_data())

func _on_continue_button_pressed() -> void:
	continue_requested.emit(_mode, _selected_index, _get_selected_item_data())
