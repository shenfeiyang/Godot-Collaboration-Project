extends Control
class_name InventoryPanel

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")
const STAT_IDS = preload("res://scripts/stats/stat_ids.gd")
const INVENTORY_SLOT_DATA_SCRIPT = preload("res://ui/inventory_slot_data.gd")
const INVENTORY_ITEM_DEFINITION_SCRIPT = preload("res://ui/inventory_item_definition.gd")
const INVENTORY_SLOT_SCENE = preload("res://ui/inventory_slot_ui.tscn")
const ITEM_DETAILS_PANEL_SCENE = preload("res://ui/item_details_panel.tscn")
const PLAYER_PREVIEW_SCENE = preload("res://characters/player/player.tscn")
const ITEM_ICON_ATLAS = preload("res://assets/texture/all_icon.png")
const STAT_MODIFIER_CONFIG_SCRIPT = preload("res://scripts/stats/stat_modifier_config.gd")
const EQUIPMENT_DEFINITION_SCRIPT = preload("res://assets/equipment/equipment_definition.gd")
const GENERATED_EQUIPMENT_DIR = "res://assets/equipment/generated"
const EQUIPMENT_SLOT_LAYOUTS = [
	{"holder_path": "WeaponSlot/SlotHolder", "equip_slot": SHARED_ENUMS.EquipSlot.WEAPON, "label": "武器"},
	{"holder_path": "HeadSlot/SlotHolder", "equip_slot": SHARED_ENUMS.EquipSlot.HEAD, "label": "头部"},
	{"holder_path": "ChestSlot/SlotHolder", "equip_slot": SHARED_ENUMS.EquipSlot.CHEST, "label": "胸甲"},
	{"holder_path": "HandsSlot/SlotHolder", "equip_slot": SHARED_ENUMS.EquipSlot.HANDS, "label": "手部"},
	{"holder_path": "LegsSlot/SlotHolder", "equip_slot": SHARED_ENUMS.EquipSlot.LEGS, "label": "腿部"},
	{"holder_path": "FeetSlot/SlotHolder", "equip_slot": SHARED_ENUMS.EquipSlot.FEET, "label": "脚部"},
	{"holder_path": "RingSlot/SlotHolder", "equip_slot": SHARED_ENUMS.EquipSlot.RING, "label": "戒指"},
	{"holder_path": "NeckSlot/SlotHolder", "equip_slot": SHARED_ENUMS.EquipSlot.NECK, "label": "项链"},
	{"holder_path": "ArtifactSlot/SlotHolder", "equip_slot": SHARED_ENUMS.EquipSlot.ARTIFACT, "label": "饰物"},
]
const EQUIPMENT_SLOT_TYPE_TO_ENUM = {
	&"weapon": SHARED_ENUMS.EquipSlot.WEAPON,
	&"helmet": SHARED_ENUMS.EquipSlot.HEAD,
	&"head": SHARED_ENUMS.EquipSlot.HEAD,
	&"armor": SHARED_ENUMS.EquipSlot.CHEST,
	&"chest": SHARED_ENUMS.EquipSlot.CHEST,
	&"gloves": SHARED_ENUMS.EquipSlot.HANDS,
	&"hands": SHARED_ENUMS.EquipSlot.HANDS,
	&"pants": SHARED_ENUMS.EquipSlot.LEGS,
	&"legs": SHARED_ENUMS.EquipSlot.LEGS,
	&"shoes": SHARED_ENUMS.EquipSlot.FEET,
	&"feet": SHARED_ENUMS.EquipSlot.FEET,
	&"bracelet": SHARED_ENUMS.EquipSlot.RING,
	&"ring": SHARED_ENUMS.EquipSlot.RING,
	&"necklace": SHARED_ENUMS.EquipSlot.NECK,
	&"neck": SHARED_ENUMS.EquipSlot.NECK,
	&"earrings": SHARED_ENUMS.EquipSlot.ARTIFACT,
	&"artifact": SHARED_ENUMS.EquipSlot.ARTIFACT,
	&"accessory": SHARED_ENUMS.EquipSlot.ARTIFACT,
}

signal closed
signal details_requested(item_definition: InventoryItemDefinition, source_role: StringName, slot_index: int)

@export var inventory_column_count: int = 10
@export var inventory_slot_count: int = 100

@onready var equipment_tab_button: BaseButton = $Root/Panel/Content/Right/Top/InventoryTabs/EquipmentTab
@onready var consumable_tab_button: BaseButton = $Root/Panel/Content/Right/Top/InventoryTabs/ConsumableTab
@onready var material_tab_button: BaseButton = $Root/Panel/Content/Right/Top/InventoryTabs/MaterialTab
@onready var capacity_label: Label = $Root/Panel/Content/Right/Top/Header/CapacityLabel
@onready var close_button: Button = $Root/Panel/Content/Right/Top/Header/CloseButton
@onready var portrait_sprite: AnimatedSprite2D = $Root/Panel/Content/Left/EquipmentPanel/Portrait
@onready var player_name_label: Label = $Root/Panel/Content/Left/EquipmentPanel/PlayerNameLabel
@onready var equipment_preview_root: Control = $Root/Panel/Content/Left/EquipmentPanel
@onready var stats_grid: GridContainer = $Root/Panel/Content/Left/StatsPanel/StatsGrid
@onready var inventory_grid: GridContainer = $Root/Panel/Content/Right/RightContent/InventoryVBox/InventoryScroll/InventoryGrid
@onready var filter_dropdown: OptionButton = $Root/Panel/Content/Right/RightContent/FilterDropdown
@onready var item_details_panel: ItemDetailsPanel = get_node_or_null("ItemDetailsPanel") as ItemDetailsPanel

var _player: Player = null
var _stats_component: StatsComponent = null
var _inventory_slots: Array[InventorySlotData] = []
var _inventory_slot_uis: Array[InventorySlotUI] = []
var _equipment_slot_uis: Dictionary = {}
var _equipped_inventory_indexes: Dictionary = {}
var _selected_visible_slot_index: int = -1
var _selected_equipment_slot: int = SHARED_ENUMS.EquipSlot.NONE
var _selected_item_definition: InventoryItemDefinition = null
var _selected_category: int = SHARED_ENUMS.ItemCategory.EQUIPMENT
var _selected_subcategory: int = SHARED_ENUMS.ItemSubcategory.ALL
var _visible_slot_indexes: Array[int] = []

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_setup_portrait_preview()
	_inventory_slots = _build_demo_inventory_slots()
	_build_equipment_preview()
	_setup_filter_dropdown()
	_wire_buttons()
	_ensure_item_details_panel()
	_setup_close_button_feedback()
	_refresh_inventory_view()
	_refresh_player_summary()

func bind_player(player: Player) -> void:
	_player = player
	_stats_component = null
	if _player != null:
		_stats_component = _player.get_node_or_null("StatsComponent") as StatsComponent
	_refresh_player_summary()

func toggle_visible() -> void:
	set_panel_visible(not visible)

func set_panel_visible(value: bool) -> void:
	visible = value
	if visible:
		_refresh_player_summary()
		_refresh_equipment_preview()
		_refresh_inventory_view()
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		set_panel_visible(false)
		closed.emit()
		accept_event()

func _wire_buttons() -> void:
	_connect_button(close_button, _on_close_button_pressed)
	_connect_button(equipment_tab_button, _on_equipment_tab_pressed)
	_connect_button(consumable_tab_button, _on_consumable_tab_pressed)
	_connect_button(material_tab_button, _on_material_tab_pressed)
	if filter_dropdown != null and not filter_dropdown.item_selected.is_connected(_on_filter_dropdown_item_selected):
		filter_dropdown.item_selected.connect(_on_filter_dropdown_item_selected)

func _connect_button(button: BaseButton, callable_ref: Callable) -> void:
	if button != null and not button.pressed.is_connected(callable_ref):
		button.pressed.connect(callable_ref)

func _setup_close_button_feedback() -> void:
	if close_button == null:
		return
	close_button.pivot_offset = close_button.size * 0.5
	if not close_button.button_down.is_connected(_on_close_button_button_down):
		close_button.button_down.connect(_on_close_button_button_down)
	if not close_button.button_up.is_connected(_on_close_button_button_up):
		close_button.button_up.connect(_on_close_button_button_up)
	_apply_close_button_scale(Vector2.ONE)

func _setup_filter_dropdown() -> void:
	if filter_dropdown == null:
		return
	filter_dropdown.clear()
	for option in _get_filter_options_for_category(_selected_category):
		filter_dropdown.add_item(String(option.get("label", "全部")), int(option.get("id", SHARED_ENUMS.ItemSubcategory.ALL)))
	_refresh_filter_styles()

func _ensure_item_details_panel() -> void:
	if item_details_panel != null:
		return
	var instantiated_panel := ITEM_DETAILS_PANEL_SCENE.instantiate() as ItemDetailsPanel
	if instantiated_panel == null:
		return
	add_child(instantiated_panel)
	item_details_panel = instantiated_panel

func _get_filter_options_for_category(category: int) -> Array[Dictionary]:
	match category:
		SHARED_ENUMS.ItemCategory.EQUIPMENT:
			return [
				{"label": "全部", "id": SHARED_ENUMS.ItemSubcategory.ALL},
				{"label": "武器", "id": SHARED_ENUMS.ItemSubcategory.WEAPON},
				{"label": "头盔", "id": SHARED_ENUMS.ItemSubcategory.HEAD},
				{"label": "胸甲", "id": SHARED_ENUMS.ItemSubcategory.CHEST},
				{"label": "手部", "id": SHARED_ENUMS.ItemSubcategory.HANDS},
				{"label": "腿部", "id": SHARED_ENUMS.ItemSubcategory.LEGS},
				{"label": "脚部", "id": SHARED_ENUMS.ItemSubcategory.FEET},
				{"label": "戒指", "id": SHARED_ENUMS.ItemSubcategory.RING},
				{"label": "项链", "id": SHARED_ENUMS.ItemSubcategory.NECK},
				{"label": "饰物", "id": SHARED_ENUMS.ItemSubcategory.ARTIFACT},
			]
		SHARED_ENUMS.ItemCategory.CONSUMABLE:
			return [
				{"label": "全部", "id": SHARED_ENUMS.ItemSubcategory.ALL},
				{"label": "药水", "id": SHARED_ENUMS.ItemSubcategory.POTION},
				{"label": "食物", "id": SHARED_ENUMS.ItemSubcategory.FOOD},
				{"label": "其他", "id": SHARED_ENUMS.ItemSubcategory.OTHER},
			]
		SHARED_ENUMS.ItemCategory.MATERIAL:
			return [
				{"label": "全部", "id": SHARED_ENUMS.ItemSubcategory.ALL},
				{"label": "矿石", "id": SHARED_ENUMS.ItemSubcategory.ORE},
				{"label": "草药", "id": SHARED_ENUMS.ItemSubcategory.HERB},
				{"label": "骨材", "id": SHARED_ENUMS.ItemSubcategory.BONE},
				{"label": "宝石", "id": SHARED_ENUMS.ItemSubcategory.GEM},
				{"label": "其他", "id": SHARED_ENUMS.ItemSubcategory.OTHER},
			]
	return [{"label": "全部", "id": SHARED_ENUMS.ItemSubcategory.ALL}]

func _apply_close_button_scale(target_scale: Vector2) -> void:
	if close_button == null:
		return
	close_button.scale = target_scale

func _build_equipment_preview() -> void:
	_equipment_slot_uis.clear()
	for slot_layout in EQUIPMENT_SLOT_LAYOUTS:
		var holder := equipment_preview_root.get_node_or_null(slot_layout.get("holder_path", "")) as Control
		_setup_equipment_slot_ui(holder, int(slot_layout.get("equip_slot", SHARED_ENUMS.EquipSlot.NONE)), String(slot_layout.get("label", "装备")))
	_refresh_equipment_preview()

func _setup_portrait_preview() -> void:
	if portrait_sprite == null:
		return
	var preview_player := PLAYER_PREVIEW_SCENE.instantiate() as Player
	if preview_player == null:
		return
	var body_sprite := preview_player.get_node_or_null("BodySprite") as AnimatedSprite2D
	if body_sprite != null and body_sprite.sprite_frames != null:
		portrait_sprite.sprite_frames = body_sprite.sprite_frames
		portrait_sprite.play(&"normal_right")
	preview_player.queue_free()
	if player_name_label != null:
		player_name_label.text = "冒险者"

func _setup_equipment_slot_ui(holder: Control, equip_slot: int, slot_label: String) -> void:
	if holder == null:
		return
	for child in holder.get_children():
		child.queue_free()
	holder.custom_minimum_size = Vector2(60, 60)
	var slot_ui := INVENTORY_SLOT_SCENE.instantiate() as InventorySlotUI
	slot_ui.custom_minimum_size = Vector2(60, 60)
	slot_ui.slot_index = equip_slot
	slot_ui.set_label_text(slot_label)
	var slot_data: InventorySlotData = INVENTORY_SLOT_DATA_SCRIPT.new()
	slot_data.setup(null, 0)
	slot_ui.bind_slot_data(slot_data)
	if not slot_ui.left_clicked.is_connected(_on_equipment_slot_left_clicked):
		slot_ui.left_clicked.connect(_on_equipment_slot_left_clicked)
	if not slot_ui.right_clicked.is_connected(_on_equipment_slot_right_clicked):
		slot_ui.right_clicked.connect(_on_equipment_slot_right_clicked)
	holder.add_child(slot_ui)
	_equipment_slot_uis[equip_slot] = slot_ui

func _refresh_inventory_view() -> void:
	if inventory_grid == null:
		return
	_visible_slot_indexes = _collect_visible_slot_indexes()
	inventory_grid.columns = max(inventory_column_count, 1)
	for child in inventory_grid.get_children():
		child.queue_free()
	_inventory_slot_uis.clear()
	for slot_index in _visible_slot_indexes:
		var slot_ui := INVENTORY_SLOT_SCENE.instantiate() as InventorySlotUI
		slot_ui.slot_index = slot_index
		slot_ui.bind_slot_data(_inventory_slots[slot_index])
		if not slot_ui.left_clicked.is_connected(_on_inventory_slot_left_clicked):
			slot_ui.left_clicked.connect(_on_inventory_slot_left_clicked)
		if not slot_ui.right_clicked.is_connected(_on_inventory_slot_right_clicked):
			slot_ui.right_clicked.connect(_on_inventory_slot_right_clicked)
		inventory_grid.add_child(slot_ui)
		_inventory_slot_uis.append(slot_ui)
	_refresh_capacity_text()
	_refresh_tab_styles()
	_refresh_filter_styles()
	_refresh_selection_after_rebuild()

func _collect_visible_slot_indexes() -> Array[int]:
	var indexes: Array[int] = []
	for index in range(_inventory_slots.size()):
		if _is_inventory_index_equipped(index):
			continue
		if _matches_current_filters(_inventory_slots[index]):
			indexes.append(index)
	return indexes

func _is_inventory_index_equipped(inventory_index: int) -> bool:
	return _find_equipped_slot_for_inventory_index(inventory_index) != SHARED_ENUMS.EquipSlot.NONE

func _matches_current_filters(slot_data: InventorySlotData) -> bool:
	if slot_data == null or slot_data.is_empty() or slot_data.item_definition == null:
		return false
	if slot_data.item_definition.category != _selected_category:
		return false
	if _selected_subcategory != SHARED_ENUMS.ItemSubcategory.ALL and slot_data.item_definition.subcategory != _selected_subcategory:
		return false
	return true

func _refresh_selection_after_rebuild() -> void:
	if _visible_slot_indexes.is_empty():
		_selected_visible_slot_index = -1
		_selected_equipment_slot = SHARED_ENUMS.EquipSlot.NONE
		_selected_item_definition = null
		_refresh_slot_selection_state()
		_refresh_selection_info(null)
		return
	if _selected_visible_slot_index < 0 or _selected_visible_slot_index >= _visible_slot_indexes.size():
		_selected_visible_slot_index = 0
		_selected_equipment_slot = SHARED_ENUMS.EquipSlot.NONE
	_refresh_slot_selection_state()
	var slot_data: InventorySlotData = _inventory_slots[_visible_slot_indexes[_selected_visible_slot_index]]
	_selected_item_definition = slot_data.item_definition if slot_data != null else null
	_refresh_selection_info(_selected_item_definition)

func _refresh_slot_selection_state() -> void:
	for index in range(_inventory_slot_uis.size()):
		var slot_ui: InventorySlotUI = _inventory_slot_uis[index]
		if slot_ui != null:
			slot_ui.set_selected(index == _selected_visible_slot_index)
	for equip_slot in _equipment_slot_uis.keys():
		var equip_slot_ui: InventorySlotUI = _equipment_slot_uis[equip_slot]
		if equip_slot_ui != null:
			equip_slot_ui.set_selected(_normalize_equip_slot(int(equip_slot)) == _selected_equipment_slot)

func _build_demo_inventory_slots() -> Array[InventorySlotData]:
	var slots: Array[InventorySlotData] = []
	var demo_items: Array[Dictionary] = _build_generated_equipment_demo_items()
	demo_items.append_array([
		{
			"definition": _create_item_definition(
				&"bread",
				"干粮面包",
				SHARED_ENUMS.ItemCategory.CONSUMABLE,
				SHARED_ENUMS.ItemSubcategory.FOOD,
				SHARED_ENUMS.ItemRarity.WHITE,
				"恢复体力用的旅行干粮。",
				20,
				SHARED_ENUMS.EquipSlot.NONE,
				[]
			),
			"quantity": 6,
		},
		{
			"definition": _create_item_definition(
				&"mana_leaf",
				"回能叶片",
				SHARED_ENUMS.ItemCategory.CONSUMABLE,
				SHARED_ENUMS.ItemSubcategory.POTION,
				SHARED_ENUMS.ItemRarity.BLUE,
				"可用于快速补充战斗中的能量。",
				10,
				SHARED_ENUMS.EquipSlot.NONE,
				[]
			),
			"quantity": 3,
		},
		{
			"definition": _create_item_definition(
				&"iron_ore",
				"铁矿石",
				SHARED_ENUMS.ItemCategory.MATERIAL,
				SHARED_ENUMS.ItemSubcategory.ORE,
				SHARED_ENUMS.ItemRarity.WHITE,
				"常见的锻造矿石，可用于制作基础装备。",
				99,
				SHARED_ENUMS.EquipSlot.NONE,
				[]
			),
			"quantity": 18,
		},
		{
			"definition": _create_item_definition(
				&"moonleaf",
				"月纹草",
				SHARED_ENUMS.ItemCategory.MATERIAL,
				SHARED_ENUMS.ItemSubcategory.HERB,
				SHARED_ENUMS.ItemRarity.GREEN,
				"带有微光的草药，是常见炼金材料。",
				99,
				SHARED_ENUMS.EquipSlot.NONE,
				[]
			),
			"quantity": 9,
		},
		{
			"definition": _create_item_definition(
				&"beast_bone",
				"兽骨碎片",
				SHARED_ENUMS.ItemCategory.MATERIAL,
				SHARED_ENUMS.ItemSubcategory.BONE,
				SHARED_ENUMS.ItemRarity.BLUE,
				"坚硬的野兽骨材，可用于强化护具。",
				99,
				SHARED_ENUMS.EquipSlot.NONE,
				[]
			),
			"quantity": 7,
		},
		{
			"definition": _create_item_definition(
				&"sun_gem",
				"日耀宝石",
				SHARED_ENUMS.ItemCategory.MATERIAL,
				SHARED_ENUMS.ItemSubcategory.GEM,
				SHARED_ENUMS.ItemRarity.PURPLE,
				"内含稳定能量的宝石，可用于高阶镶嵌。",
				99,
				SHARED_ENUMS.EquipSlot.NONE,
				[]
			),
			"quantity": 4,
		},
		{
			"definition": _create_item_definition(
				&"crystal_core",
				"结晶核心",
				SHARED_ENUMS.ItemCategory.MATERIAL,
				SHARED_ENUMS.ItemSubcategory.OTHER,
				SHARED_ENUMS.ItemRarity.PURPLE,
				"用于强化武器或解锁高阶技能的稀有素材。",
				99,
				SHARED_ENUMS.EquipSlot.NONE,
				[]
			),
			"quantity": 12,
		},
	])
	for index in range(inventory_slot_count):
		var slot_data: InventorySlotData = INVENTORY_SLOT_DATA_SCRIPT.new()
		if index < demo_items.size():
			var entry: Dictionary = demo_items[index]
			slot_data.setup(entry.get("definition", null), int(entry.get("quantity", 0)))
		else:
			slot_data.setup(null, 0)
		slots.append(slot_data)
	return slots

func _create_item_definition(item_id: StringName, display_name: String, category: int, subcategory: int, rarity: int, description: String, max_stack: int, equip_slot: int, modifiers: Array[Dictionary]) -> InventoryItemDefinition:
	var definition: InventoryItemDefinition = INVENTORY_ITEM_DEFINITION_SCRIPT.new()
	definition.item_id = item_id
	definition.display_name = display_name
	definition.category = category
	definition.subcategory = subcategory
	definition.rarity = rarity
	definition.description = description
	definition.max_stack = max_stack
	definition.equip_slot = _normalize_equip_slot(equip_slot)
	definition.stat_modifiers = []
	for modifier_data in modifiers:
		var modifier: StatModifierConfig = STAT_MODIFIER_CONFIG_SCRIPT.new()
		modifier.stat_id = modifier_data.get("stat_id", StringName())
		modifier.value = float(modifier_data.get("value", 0.0))
		definition.stat_modifiers.append(modifier)
	definition.icon = _get_default_icon(category, subcategory)
	return definition

func _create_item_definition_from_equipment(equipment_definition: EquipmentDefinition) -> InventoryItemDefinition:
	var equip_slot := _map_equipment_slot_type_to_enum(equipment_definition.slot_type)
	var subcategory := _get_subcategory_for_equip_slot(equip_slot)
	var rarity := equipment_definition.rarity if equipment_definition.rarity in SHARED_ENUMS.ItemRarity.values() else SHARED_ENUMS.ItemRarity.WHITE
	var definition := _create_item_definition(
		equipment_definition.equipment_id,
		equipment_definition.display_name,
		SHARED_ENUMS.ItemCategory.EQUIPMENT,
		subcategory,
		rarity,
		"由装备表生成的测试装备。",
		1,
		equip_slot,
		[]
	)
	definition.icon = equipment_definition.icon if equipment_definition.icon != null else _get_default_icon(definition.category, definition.subcategory)
	definition.stat_modifiers = []
	for modifier in equipment_definition.stat_modifiers:
		if modifier == null:
			continue
		var copied_modifier: StatModifierConfig = STAT_MODIFIER_CONFIG_SCRIPT.new()
		copied_modifier.stat_id = modifier.stat_id
		copied_modifier.operation = modifier.operation
		copied_modifier.value = modifier.value
		definition.stat_modifiers.append(copied_modifier)
	return definition

func _load_generated_equipment_definitions() -> Array[EquipmentDefinition]:
	var definitions: Array[EquipmentDefinition] = []
	var dir := DirAccess.open(GENERATED_EQUIPMENT_DIR)
	if dir == null:
		return definitions
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			continue
		var resource := load("%s/%s" % [GENERATED_EQUIPMENT_DIR, file_name]) as EquipmentDefinition
		if resource != null:
			definitions.append(resource)
	dir.list_dir_end()
	definitions.sort_custom(func(a: EquipmentDefinition, b: EquipmentDefinition) -> bool:
		return String(a.equipment_id) < String(b.equipment_id)
	)
	return definitions

func _build_generated_equipment_demo_items() -> Array[Dictionary]:
	var demo_items: Array[Dictionary] = []
	for equipment_definition in _load_generated_equipment_definitions():
		demo_items.append({
			"definition": _create_item_definition_from_equipment(equipment_definition),
			"quantity": 1,
		})
	return demo_items

func _get_default_icon(category: int, subcategory: int) -> Texture2D:
	var region := Rect2(0, 0, 16, 16)
	match subcategory:
		SHARED_ENUMS.ItemSubcategory.WEAPON:
			region = Rect2(16, 0, 16, 16)
		SHARED_ENUMS.ItemSubcategory.HEAD:
			region = Rect2(32, 0, 16, 16)
		SHARED_ENUMS.ItemSubcategory.CHEST:
			region = Rect2(48, 0, 16, 16)
		SHARED_ENUMS.ItemSubcategory.HANDS:
			region = Rect2(64, 0, 16, 16)
		SHARED_ENUMS.ItemSubcategory.LEGS:
			region = Rect2(80, 0, 16, 16)
		SHARED_ENUMS.ItemSubcategory.FEET:
			region = Rect2(96, 0, 16, 16)
		SHARED_ENUMS.ItemSubcategory.RING:
			region = Rect2(112, 0, 16, 16)
		SHARED_ENUMS.ItemSubcategory.NECK:
			region = Rect2(128, 0, 16, 16)
		SHARED_ENUMS.ItemSubcategory.ARTIFACT:
			region = Rect2(144, 0, 16, 16)
		SHARED_ENUMS.ItemSubcategory.FOOD:
			region = Rect2(0, 16, 16, 16)
		SHARED_ENUMS.ItemSubcategory.POTION:
			region = Rect2(16, 16, 16, 16)
		SHARED_ENUMS.ItemSubcategory.ORE:
			region = Rect2(32, 16, 16, 16)
		SHARED_ENUMS.ItemSubcategory.HERB:
			region = Rect2(48, 16, 16, 16)
		SHARED_ENUMS.ItemSubcategory.BONE:
			region = Rect2(64, 16, 16, 16)
		SHARED_ENUMS.ItemSubcategory.GEM:
			region = Rect2(80, 16, 16, 16)
		SHARED_ENUMS.ItemSubcategory.OTHER:
			region = Rect2(96, 16, 16, 16)
		_:
			match category:
				SHARED_ENUMS.ItemCategory.EQUIPMENT:
					region = Rect2(16, 0, 16, 16)
				SHARED_ENUMS.ItemCategory.CONSUMABLE:
					region = Rect2(0, 16, 16, 16)
				SHARED_ENUMS.ItemCategory.MATERIAL:
					region = Rect2(32, 16, 16, 16)
				_:
					region = Rect2(0, 0, 16, 16)
	var icon := AtlasTexture.new()
	icon.atlas = ITEM_ICON_ATLAS
	icon.region = region
	return icon

func _select_inventory_slot(slot_index: int) -> void:
	var visible_index: int = _visible_slot_indexes.find(slot_index)
	if visible_index < 0:
		return
	_selected_visible_slot_index = visible_index
	_selected_equipment_slot = SHARED_ENUMS.EquipSlot.NONE
	var slot_data: InventorySlotData = _inventory_slots[slot_index]
	_selected_item_definition = slot_data.item_definition if slot_data != null else null
	_refresh_slot_selection_state()
	_refresh_selection_info(_selected_item_definition)

func _select_equipment_slot(slot_index: int) -> void:
	_selected_visible_slot_index = -1
	_selected_equipment_slot = _normalize_equip_slot(slot_index)
	_selected_item_definition = _get_equipped_item_for_slot(_selected_equipment_slot)
	_refresh_slot_selection_state()
	_refresh_selection_info(_selected_item_definition)

func _on_inventory_slot_left_clicked(slot_index: int) -> void:
	_select_inventory_slot(slot_index)
	if _selected_item_definition != null:
		_open_item_details(_selected_item_definition, &"inventory", slot_index)

func _on_inventory_slot_right_clicked(slot_index: int) -> void:
	_select_inventory_slot(slot_index)
	if _selected_visible_slot_index < 0 or _selected_visible_slot_index >= _visible_slot_indexes.size():
		return
	var inventory_index := _visible_slot_indexes[_selected_visible_slot_index]
	if not _can_equip_inventory_item(inventory_index):
		return
	var slot_data: InventorySlotData = _inventory_slots[inventory_index]
	if slot_data == null or slot_data.item_definition == null:
		return
	_request_equip_from_inventory(inventory_index, slot_data.item_definition.equip_slot)

func _on_equipment_slot_left_clicked(slot_index: int) -> void:
	_select_equipment_slot(slot_index)
	if _selected_item_definition != null:
		_open_item_details(_selected_item_definition, &"equipment", _selected_equipment_slot)

func _on_equipment_slot_right_clicked(slot_index: int) -> void:
	_select_equipment_slot(slot_index)
	if _selected_equipment_slot == SHARED_ENUMS.EquipSlot.NONE:
		return
	if _get_equipped_inventory_index(_selected_equipment_slot) < 0:
		return
	_request_unequip_to_inventory(_selected_equipment_slot)

func _refresh_player_summary() -> void:
	player_name_label.text = "冒险者"
	_rebuild_stats_grid()

func _rebuild_stats_grid() -> void:
	if stats_grid == null:
		return
	for child in stats_grid.get_children():
		child.queue_free()
	for stat_id in _build_visible_stat_ids():
		var stat_label := Label.new()
		stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stat_label.add_theme_font_size_override("font_size", 12)
		stat_label.add_theme_color_override("font_color", Color(0.18, 0.16, 0.14, 1.0))
		stat_label.text = _format_stat_display(stat_id)
		stats_grid.add_child(stat_label)

func _build_visible_stat_ids() -> Array[StringName]:
	var visible_stat_ids: Array[StringName] = []
	if _stats_component == null or _stats_component.base_stats_config == null:
		return visible_stat_ids
	for stat_id in _stats_component.base_stats_config.get_configured_base_stat_ids():
		visible_stat_ids.append(stat_id)
	return visible_stat_ids

func _format_stat_display(stat_id: StringName) -> String:
	if _stats_component == null:
		return _format_zero_stat_display(stat_id)
	match stat_id:
		STAT_IDS.MAX_HP:
			return "%s：%.0f / %.0f" % [_get_stat_name(stat_id), _stats_component.get_current_hp(), _stats_component.get_stat(stat_id)]
		STAT_IDS.MAX_ENERGY:
			return "%s：%.0f / %.0f" % [_get_stat_name(stat_id), _stats_component.get_current_energy(), _stats_component.get_stat(stat_id)]
	if _is_percent_stat(stat_id):
		return "%s：%s" % [_get_stat_name(stat_id), _format_percent_value(_stats_component.get_stat(stat_id))]
	return "%s：%.0f" % [_get_stat_name(stat_id), _stats_component.get_stat(stat_id)]

func _format_zero_stat_display(stat_id: StringName) -> String:
	if stat_id == STAT_IDS.MAX_HP or stat_id == STAT_IDS.MAX_ENERGY:
		return "%s：0 / 0" % _get_stat_name(stat_id)
	if _is_percent_stat(stat_id):
		return "%s：0%%" % _get_stat_name(stat_id)
	return "%s：0" % _get_stat_name(stat_id)

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

func _refresh_equipment_preview() -> void:
	for equip_slot in _equipment_slot_uis.keys():
		var slot_ui: InventorySlotUI = _equipment_slot_uis[equip_slot]
		if slot_ui == null:
			continue
		var normalized_slot := _normalize_equip_slot(int(equip_slot))
		var item_definition: InventoryItemDefinition = _get_equipped_item_for_slot(normalized_slot)
		var slot_data: InventorySlotData = INVENTORY_SLOT_DATA_SCRIPT.new()
		slot_data.setup(item_definition, 1 if item_definition != null else 0)
		slot_ui.bind_slot_data(slot_data)
		slot_ui.set_label_text(_get_equip_slot_label(normalized_slot))

func _get_equipped_inventory_index(equip_slot: int) -> int:
	var normalized_slot := _normalize_equip_slot(equip_slot)
	if not _equipped_inventory_indexes.has(normalized_slot):
		return -1
	return int(_equipped_inventory_indexes[normalized_slot])

func _get_equipped_item_for_slot(equip_slot: int) -> InventoryItemDefinition:
	var inventory_index := _get_equipped_inventory_index(equip_slot)
	if inventory_index < 0 or inventory_index >= _inventory_slots.size():
		return null
	var slot_data: InventorySlotData = _inventory_slots[inventory_index]
	if slot_data == null or slot_data.is_empty():
		return null
	return slot_data.item_definition

func _find_equipped_slot_for_inventory_index(inventory_index: int) -> int:
	for equip_slot in _equipment_slot_uis.keys():
		if _get_equipped_inventory_index(int(equip_slot)) == inventory_index:
			return int(equip_slot)
	return SHARED_ENUMS.EquipSlot.NONE

func _can_equip_inventory_item(inventory_index: int) -> bool:
	if inventory_index < 0 or inventory_index >= _inventory_slots.size():
		return false
	var slot_data: InventorySlotData = _inventory_slots[inventory_index]
	if slot_data == null or slot_data.is_empty() or slot_data.item_definition == null:
		return false
	return slot_data.item_definition.category == SHARED_ENUMS.ItemCategory.EQUIPMENT and _normalize_equip_slot(slot_data.item_definition.equip_slot) != SHARED_ENUMS.EquipSlot.NONE

func _equip_inventory_item(inventory_index: int) -> void:
	if not _can_equip_inventory_item(inventory_index):
		return
	var slot_data: InventorySlotData = _inventory_slots[inventory_index]
	var equip_slot := _normalize_equip_slot(slot_data.item_definition.equip_slot)
	_equipped_inventory_indexes[equip_slot] = inventory_index
	_selected_visible_slot_index = _visible_slot_indexes.find(inventory_index)
	_selected_equipment_slot = SHARED_ENUMS.EquipSlot.NONE
	_selected_item_definition = slot_data.item_definition
	_refresh_equipment_preview()
	_refresh_inventory_view()
	_refresh_slot_selection_state()
	_refresh_selection_info(_selected_item_definition)

func _unequip_slot(equip_slot: int) -> void:
	var normalized_slot := _normalize_equip_slot(equip_slot)
	if _equipped_inventory_indexes.has(normalized_slot):
		_equipped_inventory_indexes.erase(normalized_slot)
	_selected_equipment_slot = normalized_slot
	_selected_visible_slot_index = -1
	_selected_item_definition = _get_equipped_item_for_slot(normalized_slot)
	_refresh_equipment_preview()
	_refresh_inventory_view()
	_refresh_slot_selection_state()
	_refresh_selection_info(_selected_item_definition)

func _request_equip_from_inventory(inventory_index: int, equip_slot: int) -> void:
	if not _can_equip_inventory_item(inventory_index):
		return
	var slot_data: InventorySlotData = _inventory_slots[inventory_index]
	if slot_data == null or slot_data.item_definition == null:
		return
	var normalized_target_slot := _normalize_equip_slot(equip_slot)
	if _normalize_equip_slot(slot_data.item_definition.equip_slot) != normalized_target_slot:
		return
	var previous_inventory_index := _get_equipped_inventory_index(normalized_target_slot)
	if previous_inventory_index >= 0 and previous_inventory_index != inventory_index:
		_equipped_inventory_indexes.erase(normalized_target_slot)
	_equip_inventory_item(inventory_index)

func _request_unequip_to_inventory(equip_slot: int, target_inventory_index: int = -1) -> void:
	var normalized_slot := _normalize_equip_slot(equip_slot)
	var equipped_inventory_index := _get_equipped_inventory_index(normalized_slot)
	if equipped_inventory_index < 0:
		return
	var destination_index := target_inventory_index
	if destination_index < 0:
		destination_index = equipped_inventory_index
	if destination_index < 0 or destination_index >= _inventory_slots.size():
		return
	var target_slot: InventorySlotData = _inventory_slots[destination_index]
	if target_slot != null and not target_slot.is_empty() and destination_index != equipped_inventory_index:
		return
	_unequip_slot(normalized_slot)
	_selected_visible_slot_index = _visible_slot_indexes.find(equipped_inventory_index)
	_refresh_inventory_view()
	_refresh_slot_selection_state()

func _refresh_selection_info(item_definition: InventoryItemDefinition) -> void:
	_selected_item_definition = item_definition

func _open_item_details(item_definition: InventoryItemDefinition, source_role: StringName, slot_index: int) -> void:
	if item_definition == null:
		return
	if item_details_panel != null:
		item_details_panel.show_item_details(item_definition, source_role, slot_index)
	details_requested.emit(item_definition, source_role, slot_index)

func _refresh_capacity_text() -> void:
	capacity_label.text = "容量：%d/%d" % [_count_used_slots_in_category(_selected_category), inventory_slot_count]

func _count_used_slots_in_category(category: int) -> int:
	var used_slots: int = 0
	for slot_data in _inventory_slots:
		if slot_data == null or slot_data.is_empty() or slot_data.item_definition == null:
			continue
		if slot_data.item_definition.category == category:
			used_slots += 1
	return used_slots

func _refresh_tab_styles() -> void:
	_style_tab_button(equipment_tab_button, _selected_category == SHARED_ENUMS.ItemCategory.EQUIPMENT)
	_style_tab_button(consumable_tab_button, _selected_category == SHARED_ENUMS.ItemCategory.CONSUMABLE)
	_style_tab_button(material_tab_button, _selected_category == SHARED_ENUMS.ItemCategory.MATERIAL)

func _style_tab_button(button: BaseButton, is_selected: bool) -> void:
	if button == null:
		return
	button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	button.button_pressed = is_selected

func _refresh_filter_styles() -> void:
	if filter_dropdown == null:
		return
	for index in range(filter_dropdown.item_count):
		if filter_dropdown.get_item_id(index) == _selected_subcategory:
			filter_dropdown.select(index)
			return
	if filter_dropdown.item_count > 0:
		filter_dropdown.select(0)

func _set_category(category: int) -> void:
	_selected_category = category
	_selected_subcategory = SHARED_ENUMS.ItemSubcategory.ALL
	_selected_visible_slot_index = -1
	_selected_equipment_slot = SHARED_ENUMS.EquipSlot.NONE
	_setup_filter_dropdown()
	_refresh_inventory_view()

func _set_subcategory(subcategory: int) -> void:
	_selected_subcategory = subcategory
	_selected_visible_slot_index = -1
	_selected_equipment_slot = SHARED_ENUMS.EquipSlot.NONE
	_refresh_filter_styles()
	_refresh_inventory_view()

func _get_category_text(category: int) -> String:
	match category:
		SHARED_ENUMS.ItemCategory.CONSUMABLE:
			return "消耗品"
		SHARED_ENUMS.ItemCategory.EQUIPMENT:
			return "装备"
		SHARED_ENUMS.ItemCategory.MATERIAL:
			return "材料"
		SHARED_ENUMS.ItemCategory.QUEST:
			return "任务"
	return "未知"

func _get_subcategory_text(subcategory: int) -> String:
	match subcategory:
		SHARED_ENUMS.ItemSubcategory.ALL:
			return "全部"
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
	return "未知"

func _normalize_equip_slot(equip_slot: int) -> int:
	if equip_slot == SHARED_ENUMS.EquipSlot.ACCESSORY:
		return SHARED_ENUMS.EquipSlot.ARTIFACT
	return equip_slot

func _map_equipment_slot_type_to_enum(slot_type: StringName) -> int:
	var normalized_slot_type := String(slot_type).to_lower()
	return int(EQUIPMENT_SLOT_TYPE_TO_ENUM.get(StringName(normalized_slot_type), SHARED_ENUMS.EquipSlot.NONE))

func _get_subcategory_for_equip_slot(equip_slot: int) -> int:
	match _normalize_equip_slot(equip_slot):
		SHARED_ENUMS.EquipSlot.WEAPON:
			return SHARED_ENUMS.ItemSubcategory.WEAPON
		SHARED_ENUMS.EquipSlot.HEAD:
			return SHARED_ENUMS.ItemSubcategory.HEAD
		SHARED_ENUMS.EquipSlot.CHEST:
			return SHARED_ENUMS.ItemSubcategory.CHEST
		SHARED_ENUMS.EquipSlot.HANDS:
			return SHARED_ENUMS.ItemSubcategory.HANDS
		SHARED_ENUMS.EquipSlot.LEGS:
			return SHARED_ENUMS.ItemSubcategory.LEGS
		SHARED_ENUMS.EquipSlot.FEET:
			return SHARED_ENUMS.ItemSubcategory.FEET
		SHARED_ENUMS.EquipSlot.RING:
			return SHARED_ENUMS.ItemSubcategory.RING
		SHARED_ENUMS.EquipSlot.NECK:
			return SHARED_ENUMS.ItemSubcategory.NECK
		SHARED_ENUMS.EquipSlot.ARTIFACT:
			return SHARED_ENUMS.ItemSubcategory.ARTIFACT
	return SHARED_ENUMS.ItemSubcategory.OTHER

func _get_equip_slot_label(equip_slot: int) -> String:
	match _normalize_equip_slot(equip_slot):
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
	return "装备"

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

func _on_equipment_tab_pressed() -> void:
	_set_category(SHARED_ENUMS.ItemCategory.EQUIPMENT)

func _on_consumable_tab_pressed() -> void:
	_set_category(SHARED_ENUMS.ItemCategory.CONSUMABLE)

func _on_material_tab_pressed() -> void:
	_set_category(SHARED_ENUMS.ItemCategory.MATERIAL)

func _on_filter_dropdown_item_selected(index: int) -> void:
	if filter_dropdown == null or index < 0 or index >= filter_dropdown.item_count:
		return
	_set_subcategory(filter_dropdown.get_item_id(index))

func _on_close_button_button_down() -> void:
	_apply_close_button_scale(Vector2(0.92, 0.92))

func _on_close_button_button_up() -> void:
	_apply_close_button_scale(Vector2.ONE)

func _on_close_button_pressed() -> void:
	set_panel_visible(false)
	closed.emit()
