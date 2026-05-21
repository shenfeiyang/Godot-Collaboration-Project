extends Resource
class_name GameRunConfig

# 玩家基础属性配置。
@export var player_base_stats: UnitStatsConfig
# 玩家当前装备列表；第一版主要用于汇总技能装配。
@export var equipped_items: Array[EquipmentDefinition] = []
# 当前战斗场景使用的关卡刷怪配置。
@export var stage_spawn_config: StageSpawnConfig
