extends CanvasLayer
class_name BattleHud

const STAT_IDS = preload("res://scripts/stats/stat_ids.gd")

@export var player_path: NodePath = NodePath("../Entities/Player")

@onready var hp_bar: ProgressBar = $Root/TopLeft/TopLeftVBox/TopRow/StatusBlock/HpBar
@onready var hp_label: Label = $Root/TopLeft/TopLeftVBox/TopRow/StatusBlock/HpLabel
@onready var energy_bar: ProgressBar = $Root/TopLeft/TopLeftVBox/TopRow/StatusBlock/EnergyBar
@onready var energy_label: Label = $Root/TopLeft/TopLeftVBox/TopRow/StatusBlock/EnergyLabel
@onready var bag_button: Button = $Root/TopLeft/TopLeftVBox/QuickButtons/QuickButtonsRow1/BagButton
@onready var skill_menu_button: Button = $Root/TopLeft/TopLeftVBox/QuickButtons/QuickButtonsRow1/SkillButton
@onready var choice_demo_button: Button = $Root/TopLeft/TopLeftVBox/QuickButtons/QuickButtonsRow2/ChoiceDemoButton
@onready var settlement_shop_demo_button: Button = $Root/TopLeft/TopLeftVBox/QuickButtons/QuickButtonsRow2/SettlementShopDemoButton
@onready var virtual_joystick: VirtualJoystick = $Root/BottomLeft/VirtualJoystick
@onready var basic_attack_button: SkillButtonUI = $Root/BottomRight/BasicAttackButton
@onready var skill_button_1: SkillButtonUI = $Root/BottomRight/SkillButton1
@onready var skill_button_2: SkillButtonUI = $Root/BottomRight/SkillButton2
@onready var skill_button_3: SkillButtonUI = $Root/BottomRight/SkillButton3
@onready var skill_button_4: SkillButtonUI = $Root/BottomRight/SkillButton4
@onready var inventory_panel: InventoryPanel = $Root/InventoryPanel
@onready var battle_choice_panel = $Root/BattleChoicePanel
@onready var settlement_shop_panel = $Root/SettlementShopPanel
@onready var battle_settlement_panel = $Root/BattleSettlementPanel

var _player: Player = null
var _stats_component: StatsComponent = null
var _skill_buttons: Array[SkillButtonUI] = []
var _demo_choice_mode_index: int = 0
var _demo_shop_mode_index: int = 0
var _is_settlement_showing: bool = false

func _ready() -> void:
	_skill_buttons = [basic_attack_button, skill_button_1, skill_button_2, skill_button_3, skill_button_4]
	_setup_static_ui()
	_bind_player()
	_wire_buttons()

func _process(_delta: float) -> void:
	_refresh_cooldowns()
	_sync_virtual_joystick_visual()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_toggle_inventory_panel()
		get_viewport().set_input_as_handled()

func _setup_static_ui() -> void:
	basic_attack_button.set_slot_label("普攻")
	skill_button_1.set_slot_label("技能1")
	skill_button_2.set_slot_label("技能2")
	skill_button_3.set_slot_label("技能3")
	skill_button_4.set_slot_label("技能4")
	bag_button.text = "背包"
	skill_menu_button.text = "技能"
	choice_demo_button.text = "三选一演示"
	settlement_shop_demo_button.text = "商店演示"
	if inventory_panel != null:
		inventory_panel.bind_player(_player)
		if not inventory_panel.closed.is_connected(_on_inventory_panel_closed):
			inventory_panel.closed.connect(_on_inventory_panel_closed)
	if battle_choice_panel != null:
		if not battle_choice_panel.closed.is_connected(_on_battle_choice_panel_closed):
			battle_choice_panel.closed.connect(_on_battle_choice_panel_closed)
		if not battle_choice_panel.choice_selected.is_connected(_on_battle_choice_selected):
			battle_choice_panel.choice_selected.connect(_on_battle_choice_selected)
	if settlement_shop_panel != null:
		if not settlement_shop_panel.closed.is_connected(_on_settlement_shop_panel_closed):
			settlement_shop_panel.closed.connect(_on_settlement_shop_panel_closed)
		if not settlement_shop_panel.purchase_requested.is_connected(_on_settlement_shop_purchase_requested):
			settlement_shop_panel.purchase_requested.connect(_on_settlement_shop_purchase_requested)
		if not settlement_shop_panel.refresh_requested.is_connected(_on_settlement_shop_refresh_requested):
			settlement_shop_panel.refresh_requested.connect(_on_settlement_shop_refresh_requested)
		if not settlement_shop_panel.continue_requested.is_connected(_on_settlement_shop_continue_requested):
			settlement_shop_panel.continue_requested.connect(_on_settlement_shop_continue_requested)
	if battle_settlement_panel != null:
		if not battle_settlement_panel.restart_requested.is_connected(_on_battle_settlement_restart_requested):
			battle_settlement_panel.restart_requested.connect(_on_battle_settlement_restart_requested)

func _bind_player() -> void:
	_player = get_node_or_null(player_path) as Player
	if _player == null:
		return
	_stats_component = _player.get_node_or_null("StatsComponent") as StatsComponent
	if inventory_panel != null:
		inventory_panel.bind_player(_player)
	if virtual_joystick != null and not virtual_joystick.input_changed.is_connected(_on_virtual_joystick_input_changed):
		virtual_joystick.input_changed.connect(_on_virtual_joystick_input_changed)
	if _stats_component != null:
		if not _stats_component.health_changed.is_connected(_on_health_changed):
			_stats_component.health_changed.connect(_on_health_changed)
		if not _stats_component.energy_changed.is_connected(_on_energy_changed):
			_stats_component.energy_changed.connect(_on_energy_changed)
		if not _stats_component.died.is_connected(_on_stats_died):
			_stats_component.died.connect(_on_stats_died)
		_refresh_health_display(_stats_component.get_current_hp(), _stats_component.get_stat(STAT_IDS.MAX_HP))
		_refresh_energy_display(_stats_component.get_current_energy(), _stats_component.get_stat(STAT_IDS.MAX_ENERGY))
	_refresh_cooldowns()

func _wire_buttons() -> void:
	for button in _skill_buttons:
		if button == null:
			continue
		if not button.pressed.is_connected(_on_skill_button_pressed):
			button.pressed.connect(_on_skill_button_pressed)
	if not bag_button.pressed.is_connected(_on_bag_button_pressed):
		bag_button.pressed.connect(_on_bag_button_pressed)
	if not skill_menu_button.pressed.is_connected(_on_skill_menu_button_pressed):
		skill_menu_button.pressed.connect(_on_skill_menu_button_pressed)
	if not choice_demo_button.pressed.is_connected(_on_choice_demo_button_pressed):
		choice_demo_button.pressed.connect(_on_choice_demo_button_pressed)
	if not settlement_shop_demo_button.pressed.is_connected(_on_settlement_shop_demo_button_pressed):
		settlement_shop_demo_button.pressed.connect(_on_settlement_shop_demo_button_pressed)

func _refresh_cooldowns() -> void:
	if _player == null:
		return
	for index in range(_skill_buttons.size()):
		var button: SkillButtonUI = _skill_buttons[index]
		if button == null:
			continue
		var cooldown_data: Dictionary = _player.get_skill_slot_cooldown_data(index)
		button.set_enabled_state(not _player.is_dead())
		button.set_cooldown_state(float(cooldown_data.get("remaining", 0.0)), float(cooldown_data.get("duration", 0.0)))

func _refresh_health_display(current_value: float, max_value: float) -> void:
	hp_bar.max_value = max(max_value, 1.0)
	hp_bar.value = clamp(current_value, 0.0, hp_bar.max_value)
	hp_label.text = "HP %.0f / %.0f" % [current_value, max_value]

func _refresh_energy_display(current_value: float, max_value: float) -> void:
	energy_bar.max_value = max(max_value, 1.0)
	energy_bar.value = clamp(current_value, 0.0, energy_bar.max_value)
	energy_label.text = "MP %.0f / %.0f" % [current_value, max_value]

func _on_health_changed(_old_value: float, new_value: float, max_value: float) -> void:
	_refresh_health_display(new_value, max_value)
	if inventory_panel != null and inventory_panel.visible:
		inventory_panel.bind_player(_player)

func _on_energy_changed(_old_value: float, new_value: float, max_value: float) -> void:
	_refresh_energy_display(new_value, max_value)
	if inventory_panel != null and inventory_panel.visible:
		inventory_panel.bind_player(_player)

func _on_virtual_joystick_input_changed(input_vector: Vector2) -> void:
	if _player == null:
		return
	_player.set_virtual_move_input(input_vector)

func _sync_virtual_joystick_visual() -> void:
	if virtual_joystick == null or _player == null:
		return
	if virtual_joystick.is_pointer_active():
		return
	virtual_joystick.set_visual_input(_player.get_combined_move_input())

func _on_skill_button_pressed(slot_index: int) -> void:
	if _player == null:
		return
	if _is_any_modal_visible():
		return
	_player.trigger_skill_slot(slot_index)
	_refresh_cooldowns()

func _on_bag_button_pressed() -> void:
	_toggle_inventory_panel()

func _on_skill_menu_button_pressed() -> void:
	if _is_any_modal_visible():
		return

func _on_choice_demo_button_pressed() -> void:
	if _is_any_modal_visible():
		return
	_show_demo_battle_choice()

func _on_settlement_shop_demo_button_pressed() -> void:
	if _is_any_modal_visible():
		return
	_show_demo_settlement_shop()

func _toggle_inventory_panel() -> void:
	if inventory_panel == null:
		return
	if _is_settlement_showing:
		return
	if (battle_choice_panel != null and battle_choice_panel.visible) or (settlement_shop_panel != null and settlement_shop_panel.visible) or (battle_settlement_panel != null and battle_settlement_panel.visible):
		return
	inventory_panel.toggle_visible()
	var is_inventory_open: bool = inventory_panel.visible
	get_tree().paused = is_inventory_open
	_set_combat_controls_active(not is_inventory_open)

func _set_combat_controls_active(is_active: bool) -> void:
	for button in _skill_buttons:
		if button == null:
			continue
		button.visible = is_active
	if virtual_joystick != null:
		virtual_joystick.visible = is_active

func _is_any_modal_visible() -> bool:
	return (inventory_panel != null and inventory_panel.visible) \
		or (battle_choice_panel != null and battle_choice_panel.visible) \
		or (settlement_shop_panel != null and settlement_shop_panel.visible) \
		or (battle_settlement_panel != null and battle_settlement_panel.visible)

func _show_demo_battle_choice() -> void:
	if battle_choice_panel == null:
		return
	var choice_context := _build_demo_choice_context(_demo_choice_mode_index)
	_demo_choice_mode_index = (_demo_choice_mode_index + 1) % 2
	battle_choice_panel.show_choices(choice_context)
	get_tree().paused = true
	_set_combat_controls_active(false)

func _show_demo_settlement_shop() -> void:
	if settlement_shop_panel == null:
		return
	var shop_context := _build_demo_settlement_shop_context(_demo_shop_mode_index)
	_demo_shop_mode_index = (_demo_shop_mode_index + 1) % 2
	settlement_shop_panel.show_shop(shop_context)
	get_tree().paused = true
	_set_combat_controls_active(false)

func _build_demo_choice_context(mode_index: int) -> Dictionary:
	if mode_index == 1:
		return {
			"mode": "event",
			"title": "特殊事件",
			"subtitle": "你在战斗间隙遇到了一次异变。",
			"event_text": "一座失控的祭坛出现在前方，你必须立刻做出决定。",
			"footer_hint": "特殊事件原型演示：点击任意卡片继续。",
			"allow_close": true,
			"choices": [
				{"tag": "冒险", "title": "触碰祭坛", "description": "立刻获得强力增益，但也可能附带未知代价。"},
				{"tag": "稳健", "title": "拆解碎片", "description": "回收稳定材料，获得较温和但稳定的提升。"},
				{"tag": "撤离", "title": "绕路前进", "description": "放弃本次收益，保持当前状态继续推进战斗。"},
			],
		}
	return {
		"mode": "normal",
		"title": "三选一",
		"subtitle": "击败敌人后，从三项奖励中选择一项。",
		"event_text": "",
		"footer_hint": "普通奖励原型演示：点击任意卡片继续。",
		"allow_close": true,
		"choices": [
			{"tag": "攻击", "title": "锋锐加护", "description": "提高接下来几场战斗中的输出效率。"},
			{"tag": "生存", "title": "坚壁护甲", "description": "提供更稳定的承伤能力，适合高压波次。"},
			{"tag": "资源", "title": "能量回路", "description": "缩短技能循环，提升战斗中的节奏感。"},
		],
	}

func _build_demo_settlement_shop_context(mode_index: int) -> Dictionary:
	if mode_index == 1:
		return {
			"mode": "shop_focus",
			"title": "结算商店",
			"subtitle": "你可以花费本场获得的金币，为下一段战斗补强。",
			"currency_text": "金币 126",
			"wave_text": "第 5 波结束",
			"summary_text": "",
			"status_text": "商店已刷新，本轮剩余一次免费查看机会。",
			"footer_hint": "商店聚焦原型演示：可切换商品并体验底部按钮状态。",
			"allow_close": true,
			"show_summary": false,
			"show_refresh": true,
			"show_purchase": true,
			"show_continue": true,
			"show_leave": true,
			"selected_index": 1,
			"items": [
				{
					"name": "迅捷短靴",
					"price_text": "38 金币",
					"description": "提升基础移速，方便拉扯与追击。",
					"detail_text": "轻量战靴能显著改善走位容错，尤其适合需要频繁换位的近战构筑。",
					"state_text": "可购买"
				},
				{
					"name": "过载线圈",
					"price_text": "52 金币",
					"description": "缩短关键技能的下一次冷却。",
					"detail_text": "对依赖爆发窗口的技能组提升明显，可更快转出下一轮核心连招。",
					"state_text": "推荐购买"
				},
				{
					"name": "护心符",
					"price_text": "74 金币",
					"description": "获得一次低血量保命缓冲。",
					"detail_text": "面对高压波次时更稳健，能在濒危时争取一次技能或走位机会。",
					"state_text": "价格较高"
				}
			]
		}
	return {
		"mode": "summary_shop",
		"title": "战斗结算",
		"subtitle": "本轮挑战结束，先查看结算，再决定是否购买补给。",
		"currency_text": "金币 92",
		"wave_text": "第 4 波结束",
		"summary_text": "本轮共击败 27 名敌人，获得 92 金币与 1 次补给机会。你的生命值保持在 68%，适合补一件偏进攻的商品继续推进。",
		"status_text": "战斗总结：下一波敌人数量会提升，但远程单位占比下降。",
		"footer_hint": "结算摘要原型演示：左侧展示摘要，右侧选择商品。",
		"allow_close": true,
		"show_summary": true,
		"show_refresh": false,
		"show_purchase": true,
		"show_continue": true,
		"show_leave": true,
		"selected_index": 0,
		"items": [
			{
				"name": "锋刃油",
				"price_text": "30 金币",
				"description": "短时间提高攻击收益。",
				"detail_text": "为武器附加临时锋锐效果，适合在下一波迅速清掉前排敌人。",
				"state_text": "可购买"
			},
			{
				"name": "急救包",
				"price_text": "26 金币",
				"description": "恢复部分生命值并稳定节奏。",
				"detail_text": "即时恢复生命并提供更高容错，适合当前血量较低时优先选择。",
				"state_text": "稳健选择"
			},
			{
				"name": "遗物碎片",
				"price_text": "已售罄",
				"description": "稀有材料，本轮已被拿走。",
				"detail_text": "该商品原本可用于强化被动遗物，但当前演示状态下已售罄，不可重复购买。",
				"state_text": "已售罄",
				"purchase_disabled": true
			}
		]
	}

func _close_active_modal() -> void:
	if battle_choice_panel != null and battle_choice_panel.visible:
		battle_choice_panel.visible = false
	if settlement_shop_panel != null and settlement_shop_panel.visible:
		settlement_shop_panel.visible = false
	if battle_settlement_panel != null and battle_settlement_panel.visible:
		battle_settlement_panel.hide_panel()
		_is_settlement_showing = false
	get_tree().paused = false
	_set_combat_controls_active(true)

func _show_player_death_settlement() -> void:
	if _is_settlement_showing or battle_settlement_panel == null:
		return
	_is_settlement_showing = true
	if inventory_panel != null and inventory_panel.visible:
		inventory_panel.set_panel_visible(false)
	if battle_choice_panel != null and battle_choice_panel.visible:
		battle_choice_panel.visible = false
	if settlement_shop_panel != null and settlement_shop_panel.visible:
		settlement_shop_panel.visible = false
	_set_combat_controls_active(false)
	battle_settlement_panel.show_settlement({
		"title": "战斗失败",
		"subtitle": "角色倒下后，本轮挑战已结束。",
		"summary_text": "你在本次战斗中被击败，当前进度不会继续推进。",
		"detail_text": "点击重新开始可立即重开当前场景，再次尝试本轮战斗。",
	})
	get_tree().paused = true


func _on_inventory_panel_closed() -> void:
	if _is_settlement_showing:
		return
	get_tree().paused = false
	_set_combat_controls_active(true)

func _on_battle_choice_panel_closed() -> void:
	get_tree().paused = false
	_set_combat_controls_active(true)

func _on_battle_choice_selected(_mode: StringName, _card_index: int, _card_data: Dictionary) -> void:
	_close_active_modal()

func _on_settlement_shop_panel_closed() -> void:
	get_tree().paused = false
	_set_combat_controls_active(true)

func _on_settlement_shop_purchase_requested(_mode: StringName, _item_index: int, _item_data: Dictionary) -> void:
	_close_active_modal()

func _on_settlement_shop_refresh_requested(_mode: StringName) -> void:
	if settlement_shop_panel == null:
		return
	settlement_shop_panel.show_shop(_build_demo_settlement_shop_context(1))

func _on_settlement_shop_continue_requested(_mode: StringName, _selected_item_index: int, _selected_item_data: Dictionary) -> void:
	_close_active_modal()

func _on_battle_settlement_restart_requested() -> void:
	_is_settlement_showing = false
	get_tree().paused = false
	if battle_settlement_panel != null:
		battle_settlement_panel.hide_panel()
	get_tree().reload_current_scene()

func _on_stats_died(_source: Node, _context: Dictionary) -> void:
	for button in _skill_buttons:
		if button == null:
			continue
		button.set_enabled_state(false)
	_show_player_death_settlement()
