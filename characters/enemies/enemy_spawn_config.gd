extends Resource
class_name EnemySpawnConfig

# 某一类敌人的生成配置，供 EnemySpawner 在 Inspector 中批量编排。
@export var enemy_scene: PackedScene
# 本配置要生成的敌人数。
@export_range(1, 128, 1) var spawn_count: int = 1
