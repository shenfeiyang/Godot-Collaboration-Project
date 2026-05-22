extends Resource
class_name EnemySpawnConfig

# 某一类敌人的生成配置，供 EnemySpawner 在 Inspector 中批量编排。
@export var enemy_scene: PackedScene
# 该批怪物使用的基础属性资源；未配置时保持场景内默认值。
@export var base_stats_config: UnitStatsConfig
# 本配置要生成的敌人数。
@export_range(1, 128, 1) var spawn_count: int = 1
