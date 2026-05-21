extends CanvasLayer
class_name BattleHud

const STAT_IDS = preload("res://scripts/stats/stat_ids.gd")

@export var player_path: NodePath = NodePath("../Entities/Player")

@onready var hp_bar: ProgressBar = $Root/TopLeft/TopLeftVBox/TopRow/StatusBlock/HpBar
@onready var hp_label: Label = $Root/TopLeft/TopLeftVBox/TopRow/StatusBlock/HpLabel
@onready var energy_bar: ProgressBar = $Root/TopLeft/TopLeftVBox/TopRow/StatusBlock/EnergyBar
@onready var energy_label: Label = $Root/TopLeft/TopLeftVBox/TopRow/StatusBlock/EnergyLabel
@onready var bag_button: Button = $Root/TopLeft/TopLeftVBox/QuickButtons/BagButton
@onready var skill_menu_button: Button = $Root/TopLeft/TopLeftVBox/QuickButtons/SkillButton
@onready var virtual_joystick: VirtualJoystick = $Root/BottomLeft/VirtualJoystick
@onready var basic_attack_button: SkillButtonUI = $Root/BottomRight/BasicAttackButton
@onready var skill_button_1: SkillButtonUI = $Root/BottomRight/SkillButton1
@onready var skill_button_2: SkillButtonUI = $Root/BottomRight/SkillButton2
@onready var skill_button_3: SkillButtonUI = $Root/BottomRight/SkillButton3
@onready var skill_button_4: SkillButtonUI = $Root/BottomRight/SkillButton4
@onready var inventory_panel: InventoryPanel = $Root/InventoryPanel

var _player: Player = null
var _stats_component: StatsComponent = null
var _skill_buttons: Array[SkillButtonUI] = []

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
	if inventory_panel != null:
		inventory_panel.bind_player(_player)
		if not inventory_panel.closed.is_connected(_on_inventory_panel_closed):
			inventory_panel.closed.connect(_on_inventory_panel_closed)

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
	if inventory_panel != null and inventory_panel.visible:
		return
	_player.trigger_skill_slot(slot_index)
	_refresh_cooldowns()

func _on_bag_button_pressed() -> void:
	_toggle_inventory_panel()

func _on_skill_menu_button_pressed() -> void:
	skill_menu_button.text = "技能"

func _toggle_inventory_panel() -> void:
	if inventory_panel == null:
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

func _on_inventory_panel_closed() -> void:
	get_tree().paused = false
	_set_combat_controls_active(true)

func _on_stats_died(_source: Node, _context: Dictionary) -> void:
	for button in _skill_buttons:
		if button == null:
			continue
		button.set_enabled_state(false)
