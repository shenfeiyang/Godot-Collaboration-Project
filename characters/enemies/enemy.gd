extends CharacterBody2D
class_name Enemy

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")
const PHYSICS_LAYERS = preload("res://scripts/physics_layers.gd")
const STAT_IDS = preload("res://scripts/stats/stat_ids.gd")

static var _debug_physics_total_usec: int = 0
static var _debug_physics_count: int = 0
static var _debug_last_physics_usec: int = 0

# 当前敌人所属阵营，供子弹过滤友军与自身时读取。
@export_enum("玩家", "怪物", "中立") var faction: int = SHARED_ENUMS.Faction.ENEMY
# 敌人朝目标移动时使用的速度。
@export var move_speed: float = 70.0
# 接近到该距离后停止继续贴近玩家。
@export var stop_distance: float = 8.0
# 进入停止距离前开始提前减速，降低贴脸时的来回抖动。
@export var slow_down_distance: float = 30.0

@export_group("网格导航")
# 多久允许重算一次路径，避免所有敌人每帧同时寻路。
@export_range(0.05, 1.0, 0.01) var repath_interval: float = 0.22
# 偏离当前路径多少格后强制重算。
@export_range(0, 8, 1) var repath_cell_tolerance: int = 1
# 接近路径点到该距离后切到下一个路径点。
@export var waypoint_reach_distance: float = 6.0
# 连续多久没有明显靠近当前路径点时，判定当前路径失效并重算。
@export_range(0.1, 2.0, 0.01) var path_stuck_timeout: float = 0.45
# 判定为有效接近当前路径点所需的最小距离变化。
@export var path_progress_epsilon: float = 2.0

@export_group("局部分散")
# 仅用于修正近邻拥挤的轻量分离半径。
@export var separation_radius: float = 18.0
# 仅用于缓解近邻重叠的轻量分离强度。
@export var separation_strength: float = 18.0
# 速度平滑系数，只做轻量收边。
@export_range(0.0, 1.0, 0.01) var velocity_smoothing: float = 0.20
# 朝向切换所需的最小水平领先量，避免左右接近时频繁摇头。
@export var facing_switch_hysteresis: float = 12.0
# 速度水平分量至少超过该阈值时，朝向跟随实际移动方向。
@export var facing_velocity_threshold: float = 6.0

@onready var body_sprite: AnimatedSprite2D = _resolve_body_sprite()
@onready var stats_component: StatsComponent = $StatsComponent

var target: Node2D = null
var navigation_service: GridNavigationService = null
var enemy_spatial_partition: EnemySpatialPartition = null
var _cached_desired_velocity: Vector2 = Vector2.ZERO
var _cached_separation_velocity: Vector2 = Vector2.ZERO
var _current_path: Array[Vector2] = []
var _path_index: int = 0
var _repath_cooldown_remaining: float = 0.0
var _last_target_cell: Vector2i = GridNavigationService.INVALID_CELL
var _last_path_start_cell: Vector2i = GridNavigationService.INVALID_CELL
var _path_reference_distance: float = INF
var _path_stuck_time: float = 0.0

func set_target(new_target: Node2D) -> void:
	target = new_target

func set_navigation_service(new_navigation_service: GridNavigationService) -> void:
	navigation_service = new_navigation_service

func set_enemy_spatial_partition(new_enemy_spatial_partition: EnemySpatialPartition) -> void:
	enemy_spatial_partition = new_enemy_spatial_partition

func _ready() -> void:
	collision_layer = PHYSICS_LAYERS.ENEMY_BODY_LAYER_BIT
	collision_mask = PHYSICS_LAYERS.ENEMY_BODY_MASK
	if stats_component != null and not stats_component.died.is_connected(_on_stats_died):
		stats_component.died.connect(_on_stats_died)
	_update_facing(Vector2.LEFT)
	if enemy_spatial_partition != null:
		enemy_spatial_partition.register_enemy(self)
	_repath_cooldown_remaining = _get_initial_repath_offset()

func _exit_tree() -> void:
	if enemy_spatial_partition != null:
		enemy_spatial_partition.unregister_enemy(self)

func _physics_process(delta: float) -> void:
	var started_usec := Time.get_ticks_usec()
	if stats_component != null and stats_component.is_dead():
		_reset_navigation_state()
		velocity = Vector2.ZERO
		move_and_slide()
		_update_partition_position()
		_record_debug_physics_cost(started_usec)
		return
	if target == null or not is_instance_valid(target):
		_reset_navigation_state()
		velocity = velocity.move_toward(Vector2.ZERO, _get_move_speed() * delta * 6.0)
		move_and_slide()
		_update_partition_position()
		_record_debug_physics_cost(started_usec)
		return

	_repath_cooldown_remaining = max(_repath_cooldown_remaining - delta, 0.0)
	var target_offset := target.global_position - global_position
	var distance_to_target := target_offset.length()
	if distance_to_target <= stop_distance:
		_cached_desired_velocity = Vector2.ZERO
		_cached_separation_velocity = _get_separation_velocity()
		_apply_seek_velocity(_cached_separation_velocity)
		move_and_slide()
		_update_partition_position()
		_update_facing(velocity)
		_record_debug_physics_cost(started_usec)
		return

	_refresh_path_if_needed()
	var next_waypoint := _get_current_waypoint()
	if next_waypoint == Vector2.ZERO:
		next_waypoint = target.global_position
	var waypoint_offset := next_waypoint - global_position
	if waypoint_offset.length() <= waypoint_reach_distance:
		_advance_path_waypoint()
		next_waypoint = _get_current_waypoint()
		if next_waypoint == Vector2.ZERO:
			next_waypoint = target.global_position
		waypoint_offset = next_waypoint - global_position

	_update_path_progress(waypoint_offset.length(), delta)
	_cached_desired_velocity = _get_path_follow_velocity(waypoint_offset, distance_to_target)
	_cached_separation_velocity = _get_separation_velocity()
	_apply_seek_velocity(_cached_desired_velocity + _cached_separation_velocity)
	move_and_slide()
	_update_partition_position()
	_update_facing(velocity)
	_record_debug_physics_cost(started_usec)

func _reset_navigation_state() -> void:
	_cached_desired_velocity = Vector2.ZERO
	_cached_separation_velocity = Vector2.ZERO
	_current_path.clear()
	_path_index = 0
	_last_target_cell = GridNavigationService.INVALID_CELL
	_last_path_start_cell = GridNavigationService.INVALID_CELL
	_path_reference_distance = INF
	_path_stuck_time = 0.0

func _refresh_path_if_needed() -> void:
	if navigation_service == null:
		return
	if target == null or not is_instance_valid(target):
		return
	if _repath_cooldown_remaining > 0.0 and not _needs_repath():
		return
	if _needs_repath():
		_rebuild_path()

func _needs_repath() -> bool:
	if navigation_service == null:
		return false
	if _current_path.is_empty() or _path_index >= _current_path.size():
		return true

	var current_cell := navigation_service.world_to_cell(global_position)
	var target_cell := navigation_service.world_to_cell(target.global_position)
	if current_cell == GridNavigationService.INVALID_CELL or target_cell == GridNavigationService.INVALID_CELL:
		return false
	if _last_target_cell != target_cell:
		return true
	if _last_path_start_cell == GridNavigationService.INVALID_CELL:
		return true
	if _get_cell_distance(current_cell, _last_path_start_cell) > repath_cell_tolerance:
		return true
	return _path_stuck_time >= path_stuck_timeout

func _rebuild_path() -> void:
	if navigation_service == null or target == null or not is_instance_valid(target):
		return

	_current_path = navigation_service.get_path_world(global_position, target.global_position)
	_path_index = 0
	_last_target_cell = navigation_service.world_to_cell(target.global_position)
	_last_path_start_cell = navigation_service.world_to_cell(global_position)
	_path_reference_distance = INF
	_path_stuck_time = 0.0
	_repath_cooldown_remaining = repath_interval + _get_initial_repath_offset() * 0.5

func _get_current_waypoint() -> Vector2:
	if _path_index < 0 or _path_index >= _current_path.size():
		return Vector2.ZERO
	return _current_path[_path_index]

func _advance_path_waypoint() -> void:
	if _path_index < _current_path.size():
		_path_index += 1
	if _path_index >= _current_path.size() and navigation_service != null:
		_last_path_start_cell = navigation_service.world_to_cell(global_position)

func _update_path_progress(distance_to_waypoint: float, delta: float) -> void:
	if _path_reference_distance == INF:
		_path_reference_distance = distance_to_waypoint
		_path_stuck_time = 0.0
		return
	if distance_to_waypoint <= _path_reference_distance - path_progress_epsilon:
		_path_reference_distance = distance_to_waypoint
		_path_stuck_time = 0.0
		return
	_path_stuck_time += delta

func _get_path_follow_velocity(waypoint_offset: Vector2, distance_to_target: float) -> Vector2:
	if waypoint_offset == Vector2.ZERO:
		return Vector2.ZERO

	var effective_slow_down_distance: float = max(slow_down_distance, stop_distance + 0.001)
	var speed_scale: float = 1.0
	if distance_to_target < effective_slow_down_distance:
		speed_scale = clamp((distance_to_target - stop_distance) / (effective_slow_down_distance - stop_distance), 0.0, 1.0)
	return waypoint_offset.normalized() * _get_move_speed() * speed_scale

func _get_separation_velocity() -> Vector2:
	if separation_radius <= 0.0 or separation_strength <= 0.0:
		return Vector2.ZERO

	var neighbors: Array = []
	if enemy_spatial_partition != null:
		neighbors = enemy_spatial_partition.query_neighbors(global_position, separation_radius, self)
	elif get_parent() != null:
		neighbors = get_parent().get_children()

	var push := Vector2.ZERO
	for sibling in neighbors:
		if sibling == self:
			continue
		if not sibling is Enemy:
			continue

		var offset: Vector2 = global_position - sibling.global_position
		var distance := offset.length()
		if distance >= separation_radius:
			continue
		if distance <= 0.0:
			offset = Vector2.RIGHT.rotated(float(get_instance_id() % 360) * PI / 180.0)
			distance = 0.001

		push += offset.normalized() * (1.0 - distance / separation_radius)

	if push == Vector2.ZERO:
		return Vector2.ZERO

	return push.normalized() * separation_strength

func _apply_seek_velocity(target_velocity: Vector2) -> void:
	if target_velocity.length() > move_speed:
		target_velocity = target_velocity.normalized() * move_speed
	velocity = velocity.lerp(target_velocity, velocity_smoothing)

func _update_partition_position() -> void:
	if enemy_spatial_partition == null:
		return
	enemy_spatial_partition.update_enemy_position(self, global_position)

func _record_debug_physics_cost(started_usec: int) -> void:
	_debug_last_physics_usec = Time.get_ticks_usec() - started_usec
	_debug_physics_total_usec += _debug_last_physics_usec
	_debug_physics_count += 1

static func get_debug_physics_stats() -> Dictionary:
	var average_usec := 0.0
	if _debug_physics_count > 0:
		average_usec = float(_debug_physics_total_usec) / float(_debug_physics_count)
	return {
		"last_usec": _debug_last_physics_usec,
		"average_usec": average_usec,
		"count": _debug_physics_count,
	}

func get_debug_desired_velocity() -> Vector2:
	return _cached_desired_velocity

func get_debug_separation_velocity() -> Vector2:
	return _cached_separation_velocity

func get_debug_final_velocity() -> Vector2:
	return velocity

func get_debug_path() -> Array[Vector2]:
	return _current_path.duplicate()

func get_debug_path_index() -> int:
	return _path_index

func _resolve_body_sprite() -> AnimatedSprite2D:
	var sprite := get_node_or_null("BodySprite") as AnimatedSprite2D
	if sprite != null:
		return sprite
	return get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

func _update_facing(direction: Vector2) -> void:
	if body_sprite == null:
		return
	if target == null or not is_instance_valid(target):
		return

	var facing_x: float = 0.0
	if abs(direction.x) >= facing_velocity_threshold:
		facing_x = direction.x
	else:
		var target_dx: float = target.global_position.x - global_position.x
		if abs(target_dx) >= facing_switch_hysteresis:
			facing_x = target_dx

	if facing_x == 0.0:
		return
	body_sprite.flip_h = facing_x > 0.0

func _get_cell_distance(cell_a: Vector2i, cell_b: Vector2i) -> int:
	return abs(cell_a.x - cell_b.x) + abs(cell_a.y - cell_b.y)

func _get_initial_repath_offset() -> float:
	return float(get_instance_id() % 7) * 0.01

func _get_move_speed() -> float:
	if stats_component == null:
		return move_speed
	var stat_move_speed: float = stats_component.get_stat(STAT_IDS.MOVE_SPEED)
	return stat_move_speed if stat_move_speed > 0.0 else move_speed

func _on_stats_died(_source: Node, _context: Dictionary) -> void:
	queue_free()
