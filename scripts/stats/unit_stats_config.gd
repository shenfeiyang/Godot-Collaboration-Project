extends Resource
class_name UnitStatsConfig

const STAT_IDS = preload("res://scripts/stats/stat_ids.gd")
const STAT_PROPERTY_TO_ID := {
	"max_hp": STAT_IDS.MAX_HP,
	"attack": STAT_IDS.ATTACK,
	"defense": STAT_IDS.DEFENSE,
	"max_energy": STAT_IDS.MAX_ENERGY,
	"energy_regen": STAT_IDS.ENERGY_REGEN,
	"move_speed": STAT_IDS.MOVE_SPEED,
	"attack_speed": STAT_IDS.ATTACK_SPEED,
	"crit_rate": STAT_IDS.CRIT_RATE,
	"crit_damage": STAT_IDS.CRIT_DAMAGE,
	"physical_damage_bonus": STAT_IDS.PHYSICAL_DAMAGE_BONUS,
	"wind_damage_bonus": STAT_IDS.WIND_DAMAGE_BONUS,
	"fire_damage_bonus": STAT_IDS.FIRE_DAMAGE_BONUS,
	"ice_damage_bonus": STAT_IDS.ICE_DAMAGE_BONUS,
	"lightning_damage_bonus": STAT_IDS.LIGHTNING_DAMAGE_BONUS,
	"light_damage_bonus": STAT_IDS.LIGHT_DAMAGE_BONUS,
	"dark_damage_bonus": STAT_IDS.DARK_DAMAGE_BONUS,
}

# 单位基础生命上限。
@export_group("基础资源")
@export_range(1.0, 99999.0, 1.0) var max_hp: float = 100.0
# 单位基础攻击力。
@export_group("基础战斗")
@export_range(0.0, 9999.0, 1.0) var attack: float = 10.0
# 单位基础防御力。
@export_range(0.0, 9999.0, 1.0) var defense: float = 0.0
# 单位基础暴击率；0.1 表示 10%。
@export_range(0.0, 100.0, 0.01) var crit_rate: float = 0.0
# 单位基础暴击伤害；0.5 表示 50%。
@export_range(0.0, 100.0, 0.01) var crit_damage: float = 0.0
# 单位基础能量上限。
@export_group("基础能量")
@export_range(0.0, 9999.0, 1.0) var max_energy: float = 0.0
# 单位每秒回复的基础能量。
@export_range(0.0, 999.0, 0.1) var energy_regen: float = 0.0
# 单位基础移动速度。
@export_group("基础节奏")
@export_range(0.0, 9999.0, 0.1) var move_speed: float = 120.0
# 单位基础攻击速度倍率；1 表示按脚本默认节奏。
@export_range(0.1, 10.0, 0.01) var attack_speed: float = 1.0
# 单位基础物理伤害加成；0.1 表示 10%。
@export_group("基础伤害加成")
@export_range(0.0, 100.0, 0.01) var physical_damage_bonus: float = 0.0
# 单位基础风属性伤害加成；0.1 表示 10%。
@export_range(0.0, 100.0, 0.01) var wind_damage_bonus: float = 0.0
# 单位基础火属性伤害加成；0.1 表示 10%。
@export_range(0.0, 100.0, 0.01) var fire_damage_bonus: float = 0.0
# 单位基础冰属性伤害加成；0.1 表示 10%。
@export_range(0.0, 100.0, 0.01) var ice_damage_bonus: float = 0.0
# 单位基础电属性伤害加成；0.1 表示 10%。
@export_range(0.0, 100.0, 0.01) var lightning_damage_bonus: float = 0.0
# 单位基础光属性伤害加成；0.1 表示 10%。
@export_range(0.0, 100.0, 0.01) var light_damage_bonus: float = 0.0
# 单位基础暗属性伤害加成；0.1 表示 10%。
@export_range(0.0, 100.0, 0.01) var dark_damage_bonus: float = 0.0

func get_base_stats() -> Dictionary:
	return {
		STAT_IDS.MAX_HP: max_hp,
		STAT_IDS.ATTACK: attack,
		STAT_IDS.DEFENSE: defense,
		STAT_IDS.CRIT_RATE: crit_rate,
		STAT_IDS.CRIT_DAMAGE: crit_damage,
		STAT_IDS.MAX_ENERGY: max_energy,
		STAT_IDS.ENERGY_REGEN: energy_regen,
		STAT_IDS.MOVE_SPEED: move_speed,
		STAT_IDS.ATTACK_SPEED: attack_speed,
		STAT_IDS.PHYSICAL_DAMAGE_BONUS: physical_damage_bonus,
		STAT_IDS.WIND_DAMAGE_BONUS: wind_damage_bonus,
		STAT_IDS.FIRE_DAMAGE_BONUS: fire_damage_bonus,
		STAT_IDS.ICE_DAMAGE_BONUS: ice_damage_bonus,
		STAT_IDS.LIGHTNING_DAMAGE_BONUS: lightning_damage_bonus,
		STAT_IDS.LIGHT_DAMAGE_BONUS: light_damage_bonus,
		STAT_IDS.DARK_DAMAGE_BONUS: dark_damage_bonus,
	}

func get_configured_base_stat_ids() -> Array[StringName]:
	var configured_stat_ids: Array[StringName] = []
	var seen_stat_ids: Dictionary = {}
	if resource_path.is_empty() or not FileAccess.file_exists(resource_path):
		for stat_id in get_base_stats().keys():
			configured_stat_ids.append(stat_id)
		return configured_stat_ids
	var file := FileAccess.open(resource_path, FileAccess.READ)
	if file == null:
		for stat_id in get_base_stats().keys():
			configured_stat_ids.append(stat_id)
		return configured_stat_ids
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("[") or not line.contains("="):
			continue
		var property_name := line.get_slice("=", 0).strip_edges()
		if not STAT_PROPERTY_TO_ID.has(property_name):
			continue
		var stat_id: StringName = STAT_PROPERTY_TO_ID[property_name]
		if seen_stat_ids.has(stat_id):
			continue
		seen_stat_ids[stat_id] = true
		configured_stat_ids.append(stat_id)
	return configured_stat_ids
