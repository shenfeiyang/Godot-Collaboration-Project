extends Node

# 生成目标玩家节点路径，由场景层在 Inspector 中指定。
@export_group("节点引用")
@export var player_path: NodePath
# 敌人统一挂载的容器路径，便于运行时集中管理。
@export var enemy_container_path: NodePath
# 敌人空间划分管理器路径，供新生成怪物查询局部近邻。
@export var enemy_spatial_partition_path: NodePath
# 网格导航服务路径，供新生成怪物接入共享寻路。
@export var navigation_service_path: NodePath

# 进入场景时是否自动执行一次初始生成。
@export_group("生成配置")
@export var spawn_on_ready: bool = true
# 支持配置多种敌人场景与数量。
@export var enemy_configs: Array[EnemySpawnConfig] = []
# 初始生成位置列表；敌人数多于位置数时会循环复用。
@export var initial_spawn_positions: Array[Vector2] = []
# 是否按固定间隔持续生成怪物。
@export_group("持续生成")
@export var continuous_spawn: bool = true
# 两次生成之间的时间间隔，单位为秒。
@export_range(0.1, 30.0, 0.1) var spawn_interval: float = 1.5
# 场上怪物达到上限后暂停继续生成。
@export_range(1, 512, 1) var max_alive_enemies: int = 20

var _player: Node2D = null
var _enemy_container: Node2D = null
var _enemy_spatial_partition: EnemySpatialPartition = null
var _navigation_service: GridNavigationService = null
var _spawn_position_index: int = 0
var _spawn_config_queue: Array[EnemySpawnConfig] = []
var _spawn_queue_index: int = 0
var _spawn_timer: float = 0.0

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	_enemy_container = get_node_or_null(enemy_container_path) as Node2D
	_enemy_spatial_partition = get_node_or_null(enemy_spatial_partition_path) as EnemySpatialPartition
	_navigation_service = get_node_or_null(navigation_service_path) as GridNavigationService
	_rebuild_spawn_queue()
	if spawn_on_ready:
		spawn_initial_enemies()

func _process(delta: float) -> void:
	if not continuous_spawn:
		return
	if not _can_spawn_enemy():
		return

	_spawn_timer += delta
	if _spawn_timer < spawn_interval:
		return

	_spawn_timer = 0.0
	_spawn_next_enemy()

func spawn_initial_enemies() -> void:
	if not _can_spawn_enemy(true):
		return

	_spawn_position_index = 0
	for config in _spawn_config_queue:
		_spawn_enemy(config)

func _spawn_next_enemy() -> void:
	if _spawn_config_queue.is_empty():
		return

	var config := _spawn_config_queue[_spawn_queue_index % _spawn_config_queue.size()]
	_spawn_queue_index += 1
	_spawn_enemy(config)

func _spawn_enemy(config: EnemySpawnConfig) -> void:
	var enemy_instance = config.enemy_scene.instantiate()
	if not enemy_instance is Enemy:
		push_warning("Spawned scene does not inherit Enemy")
		if enemy_instance != null:
			enemy_instance.queue_free()
		return

	var enemy := enemy_instance as Enemy
	_enemy_container.add_child(enemy)
	enemy.global_position = _get_next_spawn_position()
	enemy.set_target(_player)
	enemy.set_enemy_spatial_partition(_enemy_spatial_partition)
	enemy.set_navigation_service(_navigation_service)

func _get_next_spawn_position() -> Vector2:
	var position := initial_spawn_positions[_spawn_position_index % initial_spawn_positions.size()]
	_spawn_position_index += 1
	return position

func _rebuild_spawn_queue() -> void:
	_spawn_config_queue.clear()
	_spawn_queue_index = 0
	for config in enemy_configs:
		if config == null:
			continue
		if config.enemy_scene == null:
			continue
		for _index in config.spawn_count:
			_spawn_config_queue.append(config)

func _can_spawn_enemy(ignore_alive_limit: bool = false) -> bool:
	if _player == null:
		push_warning("EnemySpawner missing player reference")
		return false
	if _enemy_container == null:
		push_warning("EnemySpawner missing enemy container reference")
		return false
	if _enemy_spatial_partition == null:
		push_warning("EnemySpawner missing enemy spatial partition reference")
		return false
	if initial_spawn_positions.is_empty():
		push_warning("EnemySpawner requires at least one initial spawn position")
		return false
	if _spawn_config_queue.is_empty():
		push_warning("EnemySpawner requires at least one valid enemy config")
		return false
	if ignore_alive_limit:
		return true

	return _enemy_container.get_child_count() < max_alive_enemies
