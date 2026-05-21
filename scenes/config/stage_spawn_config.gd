extends Resource
class_name StageSpawnConfig

# 关卡使用的敌人生成配置列表。
@export var enemy_configs: Array[EnemySpawnConfig] = []
# 关卡初始刷怪点；敌人数多于位置数时循环复用。
@export var initial_spawn_positions: Array[Vector2] = []
# 进入场景时是否立即执行一次初始生成。
@export var spawn_on_ready: bool = true
# 是否持续按间隔补怪。
@export var continuous_spawn: bool = true
# 持续生成间隔，单位秒。
@export_range(0.1, 30.0, 0.1) var spawn_interval: float = 1.5
# 场上怪物上限。
@export_range(1, 512, 1) var max_alive_enemies: int = 20
