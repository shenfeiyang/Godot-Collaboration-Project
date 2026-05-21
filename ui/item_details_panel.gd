extends Control
class_name ItemDetailsPanel

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")
const STAT_IDS = preload("res://scripts/stats/stat_ids.gd")
const INVENTORY_SLOT_UI = preload("res://ui/inventory_slot_ui.gd")

@onready var overlay: ColorRect = $Overlay
@onready var panel: PanelContainer = $Panel
@onready var item_name_label: Label = $Panel/Margin/Content/Header/TitleBlock/ItemNameLabel
@onready var rarity_label: Label = $Panel/Margin/Content/Header/TitleBlock/MetaRow/RarityLabel
@onready var category_label: Label = $Panel/Margin/Content/Header/TitleBlock/MetaRow/CategoryLabel
@onready var close_button: Button = $Panel/Margin/Content/Header/CloseButton
@onready var item_icon: TextureRect = $Panel/Margin/Content/Body/LeftColumn/IconPanel/IconCenter/ItemIcon
@onready var source_label: Label = $Panel/Margin/Content/Body/LeftColumn/SourcePanel/SourceMargin/SourceLabel
@onready var compare_panel: PanelContainer = $Panel/Margin/Content/Body/LeftColumn/ComparePanel
@onready var compare_label: Label = $Panel/Margin/Content/Body/LeftColumn/ComparePanel/CompareMargin/CompareLabel
@onready var equip_slot_label: Label = $Panel/Margin/Content/Body/RightColumn/SummaryPanel/SummaryMargin/SummaryVBox/EquipSlotLabel
@onready var modifier_header_label: Label = $Panel/Margin/Content/Body/RightColumn/SummaryPanel/SummaryMargin/SummaryVBox/ModifierHeaderLabel
@onready var modifiers_list: VBoxContainer = $Panel/Margin/Content/Body/RightColumn/SummaryPanel/SummaryMargin/SummaryVBox/ModifiersList
@onready var state_label: Label = $Panel/Margin/Content/Body/RightColumn/StatePanel/StateMargin/StateLabel
@onready var description_label: Label = $Panel/Margin/Content/Body/RightColumn/DescriptionPanel/DescriptionMargin/DescriptionVBox/DescriptionScroll/DescriptionLabel
@onready var state_hint_label: Label = $Panel/Margin/Content/Footer/StateHintPanel/StateHintMargin/StateHintLabel

var _current_item_definition: InventoryItemDefinition = null
var _current_source_role: StringName = &""
var _current_slot_index: int = -1

func _ready() -> void:
	visible = false
	if close_button != null and not close_button.pressed.is_connected(hide_details):
		close_button.pressed.connect(hide_details)
	if overlay != null and not overlay.gui_input.is_connected(_on_overlay_gui_input):
		overlay.gui_input.connect(_on_overlay_gui_input)

func show_item_details(item_definition: InventoryItemDefinition, source_role: StringName, slot_index: int) -> void:
	if item_definition == null:
		return
	_current_item_definition = item_definition
	_current_source_role = source_role
	_current_slot_index = slot_index
	_refresh_view()
	visible = true
	move_to_front()

func hide_details() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		hide_details()
		get_viewport().set_input_as_handled()

func _on_overlay_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_details()
		accept_event()

func _refresh_view() -> void:
	if _current_item_definition == null:
		return
	item_name_label.text = _current_item_definition.display_name if not _current_item_definition.display_name.is_empty() else "未命名物品"
	rarity_label.text = _get_rarity_text(_current_item_definition.rarity)
	var rarity_color: Color = _get_rarity_color(_current_item_definition.rarity)
	rarity_label.modulate = rarity_color
	item_name_label.modulate = rarity_color
	category_label.text = _get_category_text(_current_item_definition.category, _current_item_definition.subcategory)
	item_icon.texture = _current_item_definition.icon
	source_label.text = _get_source_text(_current_source_role)
	equip_slot_label.visible = _current_item_definition.category == SHARED_ENUMS.ItemCategory.EQUIPMENT
	equip_slot_label.text = "部位：%s" % _get_equip_slot_text(_current_item_definition.equip_slot)
	description_label.text = _current_item_definition.description if not _current_item_definition.description.is_empty() else "暂无说明。"
	state_label.text = _get_state_description(_current_item_definition, _current_source_role)
	state_hint_label.text = _get_state_hint(_current_item_definition, _current_source_role)
	compare_panel.visible = _current_item_definition.category == SHARED_ENUMS.ItemCategory.EQUIPMENT
	compare_label.text = _get_compare_text(_current_source_role)
	modifier_header_label.text = "属性" if _current_item_definition.category == SHARED_ENUMS.ItemCategory.EQUIPMENT else "效果"
	_refresh_modifiers()

func _refresh_modifiers() -> void:
	for child in modifiers_list.get_children():
		child.queue_free()
	if _current_item_definition == null:
		return
	if _current_item_definition.stat_modifiers.is_empty():
		var empty_label := Label.new()
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.text = "当前状态下没有可展示的属性。"
		empty_label.add_theme_color_override("font_color", Color(0.32, 0.28, 0.22, 1.0))
		modifiers_list.add_child(empty_label)
		return
	for modifier in _current_item_definition.stat_modifiers:
		if modifier == null:
			continue
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = _format_modifier(modifier)
		label.add_theme_color_override("font_color", Color(0.18, 0.16, 0.14, 1.0))
		modifiers_list.add_child(label)

func _format_modifier(modifier: StatModifierConfig) -> String:
	var stat_name := _get_stat_name(modifier.stat_id)
	var prefix := "+"
	if modifier.value < 0.0:
		prefix = ""
	if _is_percent_stat(modifier.stat_id) or modifier.operation != SHARED_ENUMS.ModifierOperation.FLAT_ADD:
		return "%s%s%s" % [stat_name, prefix, _format_percent_value(modifier.value)]
	return "%s%s%.0f" % [stat_name, prefix, modifier.value]

func _get_rarity_color(rarity: int) -> Color:
	return INVENTORY_SLOT_UI.RARITY_COLORS.get(rarity, Color(0.92, 0.92, 0.92, 1.0))

func _get_rarity_text(rarity: int) -> String:
	match rarity:
		SHARED_ENUMS.ItemRarity.WHITE:
			return "白色品质"
		SHARED_ENUMS.ItemRarity.GREEN:
			return "绿色品质"
		SHARED_ENUMS.ItemRarity.BLUE:
			return "蓝色品质"
		SHARED_ENUMS.ItemRarity.PURPLE:
			return "紫色品质"
		SHARED_ENUMS.ItemRarity.ORANGE:
			return "橙色品质"
		SHARED_ENUMS.ItemRarity.RED:
			return "红色品质"
		SHARED_ENUMS.ItemRarity.GOLD:
			return "金色品质"
	return "未知品质"

func _get_source_text(source_role: StringName) -> String:
	match source_role:
		&"equipment":
			return "当前来源：已穿戴栏位"
		&"inventory":
			return "当前来源：背包栏位"
	return "当前来源：详情预览"

func _get_compare_text(source_role: StringName) -> String:
	if source_role == &"equipment":
		return "当前查看的是已穿戴装备，可在这里扩展和背包候选装备的对比信息。"
	return "当前查看的是背包装备，可在这里扩展与已穿戴同部位装备的对比信息。"

func _get_state_description(item_definition: InventoryItemDefinition, source_role: StringName) -> String:
	if item_definition.category == SHARED_ENUMS.ItemCategory.EQUIPMENT:
		if source_role == &"equipment":
			return "装备详情态：展示装备部位、装备属性，并预留比较区。"
		return "装备预览态：展示背包装备基础信息，并预留与已穿戴装备的比较位。"
	return "通用物品态：展示基础信息、效果或说明，后续可复用到普通道具详情。"

func _get_state_hint(item_definition: InventoryItemDefinition, source_role: StringName) -> String:
	if item_definition.category == SHARED_ENUMS.ItemCategory.EQUIPMENT:
		if source_role == &"equipment":
			return "这是原型中的装备详情/比较态入口，后续可继续补装备对比与操作按钮。"
		return "这是原型中的基础装备详情态入口，后续可继续补穿戴前后对比。"
	return "这是原型中的通用详情态入口，后续可复用到消耗品、材料等物品。"

func _get_category_text(category: int, subcategory: int) -> String:
	match category:
		SHARED_ENUMS.ItemCategory.EQUIPMENT:
			return "装备 / %s" % _get_subcategory_text(subcategory)
		SHARED_ENUMS.ItemCategory.CONSUMABLE:
			return "消耗品 / %s" % _get_subcategory_text(subcategory)
		SHARED_ENUMS.ItemCategory.MATERIAL:
			return "材料 / %s" % _get_subcategory_text(subcategory)
		SHARED_ENUMS.ItemCategory.QUEST:
			return "任务物品"
	return "物品"

func _get_subcategory_text(subcategory: int) -> String:
	match subcategory:
		SHARED_ENUMS.ItemSubcategory.WEAPON:
			return "武器"
		SHARED_ENUMS.ItemSubcategory.HEAD:
			return "头盔"
		SHARED_ENUMS.ItemSubcategory.CHEST:
			return "胸甲"
		SHARED_ENUMS.ItemSubcategory.HANDS:
			return "手部"
		SHARED_ENUMS.ItemSubcategory.LEGS:
			return "腿部"
		SHARED_ENUMS.ItemSubcategory.FEET:
			return "脚部"
		SHARED_ENUMS.ItemSubcategory.RING:
			return "戒指"
		SHARED_ENUMS.ItemSubcategory.NECK:
			return "项链"
		SHARED_ENUMS.ItemSubcategory.ARTIFACT:
			return "饰物"
		SHARED_ENUMS.ItemSubcategory.FOOD:
			return "食物"
		SHARED_ENUMS.ItemSubcategory.POTION:
			return "药水"
		SHARED_ENUMS.ItemSubcategory.ORE:
			return "矿石"
		SHARED_ENUMS.ItemSubcategory.HERB:
			return "草药"
		SHARED_ENUMS.ItemSubcategory.BONE:
			return "骨材"
		SHARED_ENUMS.ItemSubcategory.GEM:
			return "宝石"
		SHARED_ENUMS.ItemSubcategory.OTHER:
			return "其他"
	return "全部"

func _get_equip_slot_text(equip_slot: int) -> String:
	match equip_slot:
		SHARED_ENUMS.EquipSlot.WEAPON:
			return "武器"
		SHARED_ENUMS.EquipSlot.HEAD:
			return "头盔"
		SHARED_ENUMS.EquipSlot.CHEST:
			return "胸甲"
		SHARED_ENUMS.EquipSlot.HANDS:
			return "手部"
		SHARED_ENUMS.EquipSlot.LEGS:
			return "腿部"
		SHARED_ENUMS.EquipSlot.FEET:
			return "脚部"
		SHARED_ENUMS.EquipSlot.RING:
			return "戒指"
		SHARED_ENUMS.EquipSlot.NECK:
			return "项链"
		SHARED_ENUMS.EquipSlot.ARTIFACT:
			return "饰物"
	return "无"

func _get_stat_name(stat_id: StringName) -> String:
	match stat_id:
		STAT_IDS.ATTACK:
			return "攻击"
		STAT_IDS.DEFENSE:
			return "防御"
		STAT_IDS.MAX_HP:
			return "生命"
		STAT_IDS.CRIT_RATE:
			return "暴击率"
		STAT_IDS.CRIT_DAMAGE:
			return "暴击伤害"
		STAT_IDS.MAX_ENERGY:
			return "能量"
		STAT_IDS.ENERGY_REGEN:
			return "能量恢复"
		STAT_IDS.MOVE_SPEED:
			return "移速"
		STAT_IDS.ATTACK_SPEED:
			return "攻速"
		STAT_IDS.PHYSICAL_DAMAGE_BONUS:
			return "物理伤害"
		STAT_IDS.WIND_DAMAGE_BONUS:
			return "风属性伤害"
		STAT_IDS.FIRE_DAMAGE_BONUS:
			return "火属性伤害"
		STAT_IDS.ICE_DAMAGE_BONUS:
			return "冰属性伤害"
		STAT_IDS.LIGHTNING_DAMAGE_BONUS:
			return "电属性伤害"
		STAT_IDS.LIGHT_DAMAGE_BONUS:
			return "光属性伤害"
		STAT_IDS.DARK_DAMAGE_BONUS:
			return "暗属性伤害"
	return String(stat_id)

func _is_percent_stat(stat_id: StringName) -> bool:
	match stat_id:
		STAT_IDS.ATTACK_SPEED, STAT_IDS.CRIT_RATE, STAT_IDS.CRIT_DAMAGE, STAT_IDS.PHYSICAL_DAMAGE_BONUS, STAT_IDS.WIND_DAMAGE_BONUS, STAT_IDS.FIRE_DAMAGE_BONUS, STAT_IDS.ICE_DAMAGE_BONUS, STAT_IDS.LIGHTNING_DAMAGE_BONUS, STAT_IDS.LIGHT_DAMAGE_BONUS, STAT_IDS.DARK_DAMAGE_BONUS:
			return true
	return false

func _format_percent_value(value: float) -> String:
	var percent_value := value * 100.0
	if is_zero_approx(percent_value - round(percent_value)):
		return "%.0f%%" % percent_value
	return "%.1f%%" % percent_value
