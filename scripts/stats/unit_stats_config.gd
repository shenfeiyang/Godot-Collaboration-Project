extends Resource
class_name UnitStatsConfig

const STAT_IDS = preload("res://scripts/stats/stat_ids.gd")

# 单位基础生命上限。
@export_group("基础资源")
@export_range(1.0, 99999.0, 1.0) var max_hp: float = 100.0
# 单位基础攻击力。
@export_group("基础战斗")
@export_range(0.0, 9999.0, 1.0) var attack: float = 10.0
# 单位基础防御力。
@export_range(0.0, 9999.0, 1.0) var defense: float = 0.0
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

func get_base_stats() -> Dictionary:
	return {
		STAT_IDS.MAX_HP: max_hp,
		STAT_IDS.ATTACK: attack,
		STAT_IDS.DEFENSE: defense,
		STAT_IDS.MAX_ENERGY: max_energy,
		STAT_IDS.ENERGY_REGEN: energy_regen,
		STAT_IDS.MOVE_SPEED: move_speed,
		STAT_IDS.ATTACK_SPEED: attack_speed,
	}
