extends CharacterBody2D
class_name Enemy

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")
const PHYSICS_LAYERS = preload("res://scripts/physics_layers.gd")

static var _debug_physics_total_usec: int = 0
static var _debug_physics_count: int = 0
static var _debug_last_physics_usec: int = 0
static var _debug_recovery_trigger_count: int = 0
static var _debug_recovery_active_frames: int = 0
static var _debug_flow_refresh_request_count: int = 0

# 当前敌人所属阵营，供子弹过滤友军与自身时读取。
@export_enum("玩家", "怪物", "中立") var faction: int = SHARED_ENUMS.Faction.ENEMY
# 敌人朝目标移动时使用的速度。
@export var move_speed: float = 70.0
# 接近到该距离后停止继续贴近玩家。
@export var stop_distance: float = 8.0
# 进入停止距离前开始提前减速，降低贴脸时的来回抖动。
@export var slow_down_distance: float = 30.0

@export_group("局部移动")
# 低频重规划间隔，避免每帧都做完整局部决策。
@export_range(0.02, 0.5, 0.01) var replan_interval: float = 0.12
# 前向阻塞探测距离。
@export var obstacle_probe_distance: float = 20.0
# 前向阻塞探测的侧向采样偏移。
@export var obstacle_probe_radius: float = 10.0
# 两侧短射线的探测距离，用于矩形边缘擦碰修正。
@export var obstacle_side_probe_distance: float = 12.0
# 沿墙方向的短时锁定，避免外拐角处来回换边。
@export_range(0.0, 1.0, 0.01) var wall_follow_lock_duration: float = 0.16
# 绕障选边锁定时长，避免矩形正面这种对称场景里上下反复切边。
@export_range(0.0, 1.5, 0.01) var bypass_side_lock_duration: float = 0.42
# 沿墙超过该时长仍无明显进展时，改走脱困流程。
@export_range(0.05, 1.5, 0.01) var wall_follow_timeout: float = 0.36
# 退让状态持续时间。
@export_range(0.05, 1.0, 0.01) var yield_backoff_duration: float = 0.08
# 退让时使用的速度比例。
@export_range(0.1, 1.0, 0.01) var yield_backoff_speed_scale: float = 0.28
# 长时间没靠近主角时，认为当前通过策略失效。
@export_range(0.05, 1.5, 0.01) var stuck_timeout: float = 0.28
# 判定为有效接近主角所需的最小距离变化。
@export var stuck_distance_epsilon: float = 1.5
# 仅用于修正近邻拥挤的轻量分离半径。
@export var separation_radius: float = 8.0
# 仅用于缓解近邻重叠的轻量分离强度。
@export var separation_strength: float = 6.0
# 贴墙或短退时使用的分离权重，避免横向拉偏主状态。
@export_range(0.0, 1.0, 0.01) var constrained_separation_scale: float = 0.25
# 速度平滑系数，只做轻量收边。
@export_range(0.0, 1.0, 0.01) var velocity_smoothing: float = 0.20
# 贴墙状态恢复到流场直行前，需要连续保持通畅的时长。
@export_range(0.0, 0.5, 0.01) var wall_recovery_duration: float = 0.12
# 单帧目标方向最大转向速度，避免向量瞬间大角度翻转。
@export_range(0.0, 24.0, 0.1) var max_target_turn_speed: float = 10.0
# 贴墙阶段的最低前进速度比例，避免沿墙时速度塌得太低。
@export_range(0.1, 1.0, 0.01) var wall_follow_min_speed_scale: float = 0.72
# 贴墙阶段额外附带的流场前进权重，降低沿墙时的顿挫感。
@export_range(0.0, 0.6, 0.01) var wall_follow_flow_blend: float = 0.18
# 前向命中后沿墙额外前探距离，用于提前越过外拐角。
@export var wall_probe_forward_distance: float = 10.0
# 贴墙时朝流场方向恢复所需的最小对齐度。
@export_range(-1.0, 1.0, 0.01) var wall_recovery_alignment: float = 0.2
# 进入贴墙后，至少沿当前边持续前进的最短时长，避免每几帧重新判边。
@export_range(0.0, 0.8, 0.01) var wall_commit_duration: float = 0.22
# 贴边阶段朝障碍保持的法线权重，用于稳定沿同一侧滑行。
@export_range(0.0, 0.8, 0.01) var wall_normal_hold_scale: float = 0.22
# 朝向切换所需的最小水平领先量，避免左右接近时频繁摇头。
@export var facing_switch_hysteresis: float = 12.0

@onready var body_sprite: AnimatedSprite2D = _resolve_body_sprite()

var target: Node2D = null
var flow_field_manager: FlowFieldManager = null
var enemy_spatial_partition: EnemySpatialPartition = null
var _cached_desired_velocity: Vector2 = Vector2.ZERO
var _cached_avoidance_velocity: Vector2 = Vector2.ZERO
var _cached_recovery_velocity: Vector2 = Vector2.ZERO
var _cached_separation_velocity: Vector2 = Vector2.ZERO
var _stuck_reference_distance: float = INF
var _stuck_time: float = 0.0
var _recovery_time_remaining: float = 0.0
var _recovery_cooldown_remaining: float = 0.0
var _flow_refresh_cooldown_remaining: float = 0.0
var _recovery_attempts_since_progress: int = 0
var _pending_flow_refresh: bool = false
var _debug_is_recovering: bool = false

func set_target(new_target: Node2D) -> void:
	target = new_target

func set_flow_field_manager(new_flow_field_manager: FlowFieldManager) -> void:
	flow_field_manager = new_flow_field_manager

func set_enemy_spatial_partition(new_enemy_spatial_partition: EnemySpatialPartition) -> void:
	enemy_spatial_partition = new_enemy_spatial_partition

func _ready() -> void:
	collision_layer = PHYSICS_LAYERS.ENEMY_BODY_LAYER_BIT
	collision_mask = PHYSICS_LAYERS.ENEMY_BODY_MASK
	_update_facing(Vector2.LEFT)
	if enemy_spatial_partition != null:
		enemy_spatial_partition.register_enemy(self)

func _exit_tree() -> void:
	if enemy_spatial_partition != null:
		enemy_spatial_partition.unregister_enemy(self)

func _physics_process(delta: float) -> void:
	var started_usec := Time.get_ticks_usec()
	if target == null or not is_instance_valid(target):
		_reset_navigation_state()
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * delta * 6.0)
		move_and_slide()
		_update_partition_position()
		_record_debug_physics_cost(started_usec)
		return

	_update_recovery_timers(delta)
	var offset := target.global_position - global_position
	var distance_to_target := offset.length()
	_update_stuck_progress(distance_to_target, delta)

	if distance_to_target <= stop_distance:
		_cached_desired_velocity = Vector2.ZERO
		_cached_avoidance_velocity = Vector2.ZERO
		_cached_recovery_velocity = Vector2.ZERO
		_debug_is_recovering = false
		_cached_separation_velocity = _get_separation_velocity()
		_apply_seek_velocity(_cached_separation_velocity)
		move_and_slide()
		_update_partition_position()
		_update_facing(velocity)
		_record_debug_physics_cost(started_usec)
		return

	_cached_desired_velocity = _get_flow_desired_velocity(offset)
	_cached_avoidance_velocity = _get_avoidance_velocity(_cached_desired_velocity)
	_cached_recovery_velocity = _get_recovery_velocity(_cached_desired_velocity, offset)
	_debug_is_recovering = _cached_recovery_velocity != Vector2.ZERO
	if _debug_is_recovering:
		_debug_recovery_active_frames += 1
	if _debug_is_recovering and _pending_flow_refresh:
		_try_force_refresh_flow_field()
	_cached_separation_velocity = _get_separation_velocity()
	var primary_velocity := _cached_recovery_velocity if _debug_is_recovering else (_cached_desired_velocity + _cached_avoidance_velocity)
	var steering_velocity := primary_velocity + _cached_separation_velocity
	var next_velocity := _rotate_velocity_toward(velocity, steering_velocity, delta)
	_apply_seek_velocity(next_velocity)
	move_and_slide()
	_update_partition_position()
	_update_facing(velocity)
	_record_debug_physics_cost(started_usec)

func _reset_navigation_state() -> void:
	_cached_desired_velocity = Vector2.ZERO
	_cached_avoidance_velocity = Vector2.ZERO
	_cached_recovery_velocity = Vector2.ZERO
	_cached_separation_velocity = Vector2.ZERO
	_stuck_reference_distance = INF
	_stuck_time = 0.0
	_recovery_time_remaining = 0.0
	_recovery_cooldown_remaining = 0.0
	_flow_refresh_cooldown_remaining = 0.0
	_recovery_attempts_since_progress = 0
	_pending_flow_refresh = false
	_debug_is_recovering = false

func _update_recovery_timers(delta: float) -> void:
	_recovery_time_remaining = max(_recovery_time_remaining - delta, 0.0)
	_recovery_cooldown_remaining = max(_recovery_cooldown_remaining - delta, 0.0)
	_flow_refresh_cooldown_remaining = max(_flow_refresh_cooldown_remaining - delta, 0.0)
	if _recovery_time_remaining <= 0.0:
		_cached_recovery_velocity = Vector2.ZERO
		_debug_is_recovering = false

func _update_stuck_progress(distance_to_target: float, delta: float) -> void:
	if _debug_is_recovering:
		_stuck_reference_distance = distance_to_target
		_stuck_time = 0.0
		return
	if _stuck_reference_distance == INF:
		_stuck_reference_distance = distance_to_target
		_stuck_time = 0.0
		return
	if distance_to_target <= _stuck_reference_distance - stuck_distance_epsilon:
		_stuck_reference_distance = distance_to_target
		_stuck_time = 0.0
		_recovery_attempts_since_progress = 0
		return
	_stuck_time += delta

func _should_trigger_recovery(distance_to_target: float, desired_velocity: Vector2) -> bool:
	if distance_to_target > recovery_trigger_distance:
		return false
	if desired_velocity == Vector2.ZERO:
		return false
	if _recovery_time_remaining > 0.0 or _recovery_cooldown_remaining > 0.0:
		return false
	return _stuck_time >= stuck_timeout

func _get_flow_desired_velocity(offset: Vector2) -> Vector2:
	var move_direction := _get_flow_move_direction(offset)
	var distance := offset.length()
	if distance <= stop_distance:
		return Vector2.ZERO

	var effective_slow_down_distance: float = max(slow_down_distance, stop_distance + 0.001)
	var speed_scale: float = 1.0
	if distance < effective_slow_down_distance:
		speed_scale = clamp((distance - stop_distance) / (effective_slow_down_distance - stop_distance), 0.0, 1.0)

	return move_direction * move_speed * speed_scale

func _get_flow_move_direction(offset: Vector2) -> Vector2:
	var move_direction := offset.normalized()
	if flow_field_manager != null:
		var flow_direction := flow_field_manager.get_flow_direction(global_position)
		if flow_direction != Vector2.ZERO:
			move_direction = flow_direction

	return move_direction

func _detect_world_block(direction: Vector2) -> Dictionary:
	if direction == Vector2.ZERO:
		return {}

	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var probe_origin: Vector2 = global_position
	var forward_point: Vector2 = probe_origin + direction * obstacle_probe_distance
	var right: Vector2 = Vector2(direction.y, -direction.x)
	var left: Vector2 = -right
	var samples: Array[Dictionary] = [
		{
			"to": forward_point,
		},
		{
			"to": probe_origin + direction * obstacle_side_probe_distance + right * obstacle_probe_radius,
		},
		{
			"to": probe_origin + direction * obstacle_side_probe_distance + left * obstacle_probe_radius,
		},
	]

	for sample in samples:
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(probe_origin, sample.to, PHYSICS_LAYERS.WORLD_LAYER_BIT)
		query.exclude = [get_rid()]
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			continue

		return {
			"normal": hit.normal,
			"position": hit.position,
		}

	return {}

func _get_avoidance_velocity(desired_velocity: Vector2) -> Vector2:
	if desired_velocity == Vector2.ZERO:
		return Vector2.ZERO

	var desired_direction: Vector2 = desired_velocity.normalized()
	var world_hit: Dictionary = _detect_world_block(desired_direction)
	if world_hit.is_empty():
		return Vector2.ZERO

	var hit_normal: Vector2 = world_hit.get("normal", Vector2.ZERO)
	if hit_normal == Vector2.ZERO:
		return Vector2.ZERO

	var tangent_a: Vector2 = Vector2(-hit_normal.y, hit_normal.x).normalized()
	var tangent_b: Vector2 = -tangent_a
	var avoid_direction := tangent_a if tangent_a.dot(desired_direction) >= tangent_b.dot(desired_direction) else tangent_b
	if avoid_direction == Vector2.ZERO:
		return Vector2.ZERO

	return avoid_direction * desired_velocity.length()

func _get_recovery_velocity(desired_velocity: Vector2, target_offset: Vector2) -> Vector2:
	if _recovery_time_remaining > 0.0:
		return _cached_recovery_velocity
	if not _should_trigger_recovery(target_offset.length(), desired_velocity):
		_pending_flow_refresh = false
		return Vector2.ZERO

	var recovery_velocity: Vector2 = _build_recovery_velocity(desired_velocity, target_offset)
	if recovery_velocity == Vector2.ZERO:
		_recovery_attempts_since_progress += 1
		_pending_flow_refresh = _recovery_attempts_since_progress >= forced_refresh_attempt_threshold
		_recovery_cooldown_remaining = recovery_cooldown
		_stuck_reference_distance = INF
		_stuck_time = 0.0
		return Vector2.ZERO

	_cached_recovery_velocity = recovery_velocity
	_recovery_time_remaining = recovery_duration
	_recovery_cooldown_remaining = recovery_cooldown
	_recovery_attempts_since_progress += 1
	_debug_recovery_trigger_count += 1
	_pending_flow_refresh = _recovery_attempts_since_progress >= forced_refresh_attempt_threshold and _flow_refresh_cooldown_remaining <= 0.0
	_stuck_reference_distance = INF
	_stuck_time = 0.0
	return _cached_recovery_velocity

func _build_recovery_velocity(desired_velocity: Vector2, target_offset: Vector2) -> Vector2:
	var desired_direction: Vector2 = desired_velocity.normalized()
	var recovery_speed: float = max(desired_velocity.length() * recovery_speed_scale, move_speed * recovery_speed_scale)
	var world_hit: Dictionary = _detect_world_block(desired_direction)
	if not world_hit.is_empty():
		var hit_normal: Vector2 = world_hit.get("normal", Vector2.ZERO)
		if hit_normal != Vector2.ZERO:
			var tangent_a: Vector2 = Vector2(-hit_normal.y, hit_normal.x).normalized()
			var tangent_b: Vector2 = -tangent_a
			var tangent: Vector2 = tangent_a if tangent_a.dot(desired_direction) >= tangent_b.dot(desired_direction) else tangent_b
			var recovery_direction: Vector2 = (tangent * recovery_tangent_scale + hit_normal * recovery_normal_scale).normalized()
			if recovery_direction != Vector2.ZERO:
				return recovery_direction * recovery_speed

	var fallback_direction: Vector2 = -desired_direction
	if fallback_direction == Vector2.ZERO and target_offset != Vector2.ZERO:
		fallback_direction = -target_offset.normalized()
	if fallback_direction == Vector2.ZERO:
		fallback_direction = Vector2.LEFT
	return fallback_direction * recovery_speed

func _try_force_refresh_flow_field() -> void:
	if not _pending_flow_refresh:
		return
	_pending_flow_refresh = false
	if flow_field_manager == null or _flow_refresh_cooldown_remaining > 0.0:
		return
	flow_field_manager.request_forced_refresh()
	_debug_flow_refresh_request_count += 1
	_flow_refresh_cooldown_remaining = flow_refresh_cooldown

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

func _rotate_velocity_toward(current_velocity: Vector2, target_velocity: Vector2, delta: float) -> Vector2:
	if target_velocity == Vector2.ZERO:
		return Vector2.ZERO
	if current_velocity == Vector2.ZERO:
		return target_velocity

	var current_length := current_velocity.length()
	var target_length := target_velocity.length()
	var current_direction := current_velocity / current_length if current_length > 0.0 else target_velocity.normalized()
	var target_direction := target_velocity / target_length if target_length > 0.0 else current_direction
	var turn_ratio: float = clamp(max_target_turn_speed * delta, 0.0, 1.0)
	var blended_direction := current_direction.slerp(target_direction, turn_ratio).normalized()
	var blended_speed := lerpf(current_length, target_length, turn_ratio)
	return blended_direction * blended_speed

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
		"recovery_trigger_count": _debug_recovery_trigger_count,
		"recovery_active_frames": _debug_recovery_active_frames,
		"flow_refresh_request_count": _debug_flow_refresh_request_count,
	}

func get_debug_desired_velocity() -> Vector2:
	return _cached_desired_velocity

func get_debug_avoidance_velocity() -> Vector2:
	return _cached_avoidance_velocity

func get_debug_recovery_velocity() -> Vector2:
	return _cached_recovery_velocity

func get_debug_separation_velocity() -> Vector2:
	return _cached_separation_velocity

func get_debug_final_velocity() -> Vector2:
	return velocity

func get_debug_is_recovering() -> bool:
	return _debug_is_recovering

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

	var target_dx: float = target.global_position.x - global_position.x
	if body_sprite.flip_h:
		if target_dx < -facing_switch_hysteresis:
			body_sprite.flip_h = false
	else:
		if target_dx > facing_switch_hysteresis:
			body_sprite.flip_h = true
