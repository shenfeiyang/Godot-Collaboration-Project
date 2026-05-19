extends Node
class_name StatsComponent

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")
const STAT_IDS = preload("res://scripts/stats/stat_ids.gd")
const BUFF_RUNTIME = preload("res://scripts/stats/buff_runtime.gd")

signal health_changed(old_value: float, new_value: float, max_value: float)
signal energy_changed(old_value: float, new_value: float, max_value: float)
signal died(source: Node, context: Dictionary)
signal buff_added(buff_runtime: BuffRuntime)
signal buff_removed(buff_runtime: BuffRuntime)

# 单位基础面板资源。
@export var base_stats_config: UnitStatsConfig
# 进入场景时是否自动补满生命。
@export var initialize_full_health: bool = true
# 进入场景时是否自动补满能量。
@export var initialize_full_energy: bool = true

var current_hp: float = 0.0
var current_energy: float = 0.0

var _final_stats: Dictionary = {}
var _stats_dirty: bool = true
var _active_buffs: Array[BuffRuntime] = []
var _is_dead: bool = false

func _ready() -> void:
	_rebuild_stats_if_needed()
	var max_hp_value: float = get_stat(STAT_IDS.MAX_HP)
	var max_energy_value: float = get_stat(STAT_IDS.MAX_ENERGY)
	if initialize_full_health or current_hp <= 0.0:
		current_hp = max_hp_value
	else:
		current_hp = clamp(current_hp, 0.0, max_hp_value)
	if initialize_full_energy:
		current_energy = max_energy_value
	else:
		current_energy = clamp(current_energy, 0.0, max_energy_value)

func _process(delta: float) -> void:
	_update_buffs(delta)
	_regenerate_energy(delta)

func get_stat(stat_id: StringName) -> float:
	_rebuild_stats_if_needed()
	return float(_final_stats.get(stat_id, 0.0))

func get_current_hp() -> float:
	return current_hp

func get_current_energy() -> float:
	return current_energy

func get_hp_ratio() -> float:
	var max_hp_value: float = get_stat(STAT_IDS.MAX_HP)
	if max_hp_value <= 0.0:
		return 0.0
	return current_hp / max_hp_value

func is_dead() -> bool:
	return _is_dead

func apply_damage(damage_packet: Dictionary) -> Dictionary:
	if _is_dead:
		return {"applied_damage": 0.0, "is_killing_blow": false}

	var incoming_damage: float = float(damage_packet.get("damage", 0.0))
	var attack_value: float = float(damage_packet.get("attack", 0.0))
	var base_damage: float = max(incoming_damage, attack_value)
	if base_damage <= 0.0:
		return {"applied_damage": 0.0, "is_killing_blow": false}

	var defense_value: float = get_stat(STAT_IDS.DEFENSE)
	var applied_damage: float = max(1.0, base_damage * 100.0 / (100.0 + max(defense_value, 0.0)))
	var old_hp: float = current_hp
	current_hp = clamp(current_hp - applied_damage, 0.0, get_stat(STAT_IDS.MAX_HP))
	health_changed.emit(old_hp, current_hp, get_stat(STAT_IDS.MAX_HP))

	var is_killing_blow: bool = current_hp <= 0.0
	if is_killing_blow:
		_is_dead = true
		died.emit(damage_packet.get("source", null), damage_packet)

	return {
		"applied_damage": applied_damage,
		"is_killing_blow": is_killing_blow,
	}

func apply_heal(amount: float) -> float:
	if amount <= 0.0 or _is_dead:
		return 0.0
	var old_hp: float = current_hp
	current_hp = clamp(current_hp + amount, 0.0, get_stat(STAT_IDS.MAX_HP))
	health_changed.emit(old_hp, current_hp, get_stat(STAT_IDS.MAX_HP))
	return current_hp - old_hp

func spend_energy(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if current_energy < amount:
		return false
	var old_energy: float = current_energy
	current_energy = clamp(current_energy - amount, 0.0, get_stat(STAT_IDS.MAX_ENERGY))
	energy_changed.emit(old_energy, current_energy, get_stat(STAT_IDS.MAX_ENERGY))
	return true

func restore_energy(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var old_energy: float = current_energy
	current_energy = clamp(current_energy + amount, 0.0, get_stat(STAT_IDS.MAX_ENERGY))
	energy_changed.emit(old_energy, current_energy, get_stat(STAT_IDS.MAX_ENERGY))
	return current_energy - old_energy

func add_buff(buff_config: BuffConfig, source: Node = null) -> BuffRuntime:
	if buff_config == null:
		return null

	if buff_config.stacking_rule == SHARED_ENUMS.BuffStackingRule.INDEPENDENT_INSTANCE:
		return _append_new_buff(buff_config, source)

	for runtime in _active_buffs:
		if runtime == null or runtime.config == null:
			continue
		if runtime.config.buff_id != buff_config.buff_id:
			continue
		if buff_config.stacking_rule == SHARED_ENUMS.BuffStackingRule.REFRESH_DURATION:
			runtime.refresh_duration()
			return runtime
		runtime.add_stack()
		runtime.refresh_duration()
		_stats_dirty = true
		return runtime

	return _append_new_buff(buff_config, source)

func remove_buff(buff_id: StringName) -> void:
	for index in range(_active_buffs.size() - 1, -1, -1):
		var runtime: BuffRuntime = _active_buffs[index]
		if runtime == null or runtime.config == null:
			continue
		if runtime.config.buff_id != buff_id:
			continue
		_active_buffs.remove_at(index)
		_stats_dirty = true
		buff_removed.emit(runtime)

func get_active_buffs() -> Array[BuffRuntime]:
	return _active_buffs.duplicate()

func _append_new_buff(buff_config: BuffConfig, source: Node) -> BuffRuntime:
	var runtime: BuffRuntime = BUFF_RUNTIME.new(buff_config, source) as BuffRuntime
	_active_buffs.append(runtime)
	_stats_dirty = true
	buff_added.emit(runtime)
	return runtime

func _update_buffs(delta: float) -> void:
	for index in range(_active_buffs.size() - 1, -1, -1):
		var runtime: BuffRuntime = _active_buffs[index]
		if runtime == null:
			_active_buffs.remove_at(index)
			_stats_dirty = true
			continue
		if not runtime.tick(delta):
			continue
		_active_buffs.remove_at(index)
		_stats_dirty = true
		buff_removed.emit(runtime)

func _regenerate_energy(delta: float) -> void:
	if _is_dead:
		return
	var energy_regen_value: float = get_stat(STAT_IDS.ENERGY_REGEN)
	if energy_regen_value <= 0.0:
		return
	if current_energy >= get_stat(STAT_IDS.MAX_ENERGY):
		return
	var old_energy: float = current_energy
	current_energy = clamp(current_energy + energy_regen_value * delta, 0.0, get_stat(STAT_IDS.MAX_ENERGY))
	if not is_equal_approx(old_energy, current_energy):
		energy_changed.emit(old_energy, current_energy, get_stat(STAT_IDS.MAX_ENERGY))

func _rebuild_stats_if_needed() -> void:
	if not _stats_dirty:
		return

	var base_stats: Dictionary = {}
	if base_stats_config != null:
		base_stats = base_stats_config.get_base_stats()

	var final_stats: Dictionary = base_stats.duplicate(true)
	var flat_adds: Dictionary = {}
	var percent_adds: Dictionary = {}
	var percent_muls: Dictionary = {}
	for runtime in _active_buffs:
		if runtime == null:
			continue
		for modifier in runtime.get_modifiers():
			if modifier == null or modifier.stat_id == StringName():
				continue
			var stack_multiplier: float = float(runtime.stacks)
			match modifier.operation:
				SHARED_ENUMS.ModifierOperation.FLAT_ADD:
					flat_adds[modifier.stat_id] = float(flat_adds.get(modifier.stat_id, 0.0)) + modifier.value * stack_multiplier
				SHARED_ENUMS.ModifierOperation.PERCENT_ADD:
					percent_adds[modifier.stat_id] = float(percent_adds.get(modifier.stat_id, 0.0)) + modifier.value * stack_multiplier
				SHARED_ENUMS.ModifierOperation.PERCENT_MUL:
					var current_mul: float = float(percent_muls.get(modifier.stat_id, 1.0))
					percent_muls[modifier.stat_id] = current_mul * pow(1.0 + modifier.value, stack_multiplier)

	var stat_ids: Dictionary = {}
	for stat_id in base_stats.keys():
		stat_ids[stat_id] = true
	for stat_id in flat_adds.keys():
		stat_ids[stat_id] = true
	for stat_id in percent_adds.keys():
		stat_ids[stat_id] = true
	for stat_id in percent_muls.keys():
		stat_ids[stat_id] = true

	for stat_id in stat_ids.keys():
		var base_value: float = float(base_stats.get(stat_id, 0.0))
		var flat_value: float = float(flat_adds.get(stat_id, 0.0))
		var percent_add_value: float = float(percent_adds.get(stat_id, 0.0))
		var percent_mul_value: float = float(percent_muls.get(stat_id, 1.0))
		final_stats[stat_id] = max((base_value + flat_value) * (1.0 + percent_add_value) * percent_mul_value, 0.0)

	_final_stats = final_stats
	_stats_dirty = false
	current_hp = clamp(current_hp, 0.0, float(_final_stats.get(STAT_IDS.MAX_HP, current_hp)))
	current_energy = clamp(current_energy, 0.0, float(_final_stats.get(STAT_IDS.MAX_ENERGY, current_energy)))
