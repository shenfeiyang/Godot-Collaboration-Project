extends Area2D
class_name Bullet

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")
const PHYSICS_LAYERS = preload("res://scripts/physics_layers.gd")

# 子弹命中后统一向外发出事件，方便未来接伤害层或命中特效。
signal hit_registered(hit_data: Dictionary)

# 与发射请求约定保持一致，供初始化时读取单颗子弹的覆盖参数。
const SETUP_SPEED_OVERRIDE := "speed_override"
const SETUP_DAMAGE := "damage"
const SETUP_EXTRA := "extra"

# 子弹基础飞行速度，单位为像素/秒。
@export var speed: float = 320.0
# 子弹最大存活时间，防止未命中时永久留在场景中。
@export var max_lifetime: float = 2.0

# 子弹当前的飞行方向。
var direction: Vector2 = Vector2.RIGHT
# 生成这颗子弹的发射者，用于忽略自身碰撞。
var source: Node = null
# 子弹所属阵营，默认视为中立。
var faction: SHARED_ENUMS.Faction = SHARED_ENUMS.Faction.NEUTRAL
# 本次飞行实际使用的速度，便于单次发射做覆盖而不污染默认配置。
var current_speed: float = 0.0
# 剩余存活时间，递减到 0 后自动销毁。
var remaining_lifetime: float = 0.0
# 本次发射附带的额外上下文，供命中回调继续向外传递。
var shot_context: Dictionary = {}
# 命中只允许结算一次，避免射线检测和碰撞信号重复触发时重复上报。
var has_resolved_hit: bool = false

func _ready() -> void:
	# 绑定区域和刚体两类碰撞信号；运行时状态统一在 setup() 内重置，便于未来接对象池。
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func setup(initial_direction: Vector2, initial_source: Node = null, initial_faction: SHARED_ENUMS.Faction = SHARED_ENUMS.Faction.NEUTRAL, setup_data: Dictionary = {}) -> void:
	# 由外部在生成子弹后调用，统一注入方向、发射者、阵营与本次发射的覆盖参数。
	source = initial_source
	faction = initial_faction
	current_speed = float(setup_data.get(SETUP_SPEED_OVERRIDE, speed))
	remaining_lifetime = max_lifetime
	shot_context = setup_data.duplicate(true)
	has_resolved_hit = false
	_configure_collision_layers()

	if initial_direction != Vector2.ZERO:
		direction = initial_direction.normalized()
	else:
		direction = Vector2.RIGHT

	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	# 命中已经确定后不再继续移动，避免同一帧内重复结算。
	if has_resolved_hit:
		return

	# 每帧先检测飞行路径是否会撞到世界或敌对单位，再更新位置并处理超时回收。
	var current_position := global_position
	var next_position := current_position + direction * current_speed * delta
	var hit_target = _find_collision_target(current_position, next_position)
	if hit_target != null:
		_handle_hit(hit_target)
		return

	global_position = next_position

	# 没有命中任何对象时，也要在超时后自动清理。
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0:
		queue_free()

func _find_collision_target(from_position: Vector2, to_position: Vector2) -> Variant:
	# 使用射线查询检测当前这一帧的飞行路径，避免子弹穿过零厚度边界或薄墙体。
	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return null

	# 构建射线查询参数，设置碰撞层级和过滤选项。
	var query := PhysicsRayQueryParameters2D.create(
		from_position,
		to_position,
		collision_mask
	)
	query.collide_with_bodies = true
	query.collide_with_areas = true

	# 发射者自身不参与本次射线命中，避免刚出枪口就撞到自己。
	if source is CollisionObject2D:
		query.exclude = [source.get_rid()]

	# 发射射线并处理结果，忽略不应该命中的目标。
	var hit_result: Dictionary = space_state.intersect_ray(query)
	if hit_result.is_empty():
		return null

	var collider = hit_result.get("collider")
	if _should_ignore_target(collider):
		return null

	return collider

func _on_area_entered(area: Area2D) -> void:
	# 与 Area2D 碰撞后统一走命中出口，同时忽略其他子弹、发射者自身和同阵营目标。
	if _should_ignore_target(area):
		return

	_handle_hit(area)

func _on_body_entered(body: Node2D) -> void:
	# 与 PhysicsBody2D 碰撞后统一走命中出口，同时忽略发射者自身和同阵营目标。
	if _should_ignore_target(body):
		return

	_handle_hit(body)

func _handle_hit(target: Variant) -> void:
	# 命中时先向外抛出统一事件，再销毁子弹，后续接伤害系统时只需要扩展这里。
	if has_resolved_hit:
		return

	has_resolved_hit = true
	hit_registered.emit({
		"target": target,
		"position": global_position,
		"direction": direction,
		"source": source,
		"faction": int(faction),
		SETUP_DAMAGE: shot_context.get(SETUP_DAMAGE, null),
		SETUP_EXTRA: shot_context.get(SETUP_EXTRA, {}),
	})
	queue_free()

func _should_ignore_target(target: Variant) -> bool:
	# 统一判断一个目标是否应该被这颗子弹忽略。
	if target == null:
		return true

	if target is Bullet:
		return true

	if target == source:
		return true

	if _has_same_faction(target):
		return true

	return false

func _has_same_faction(target: Variant) -> bool:
	# 读取目标节点的阵营字段，并在一致时视为友方碰撞。
	if not target is Node:
		return false

	if not "faction" in target:
		return false

	return int(target.faction) == int(faction)

func _configure_collision_layers() -> void:
	collision_layer = PHYSICS_LAYERS.get_bullet_layer_bit(int(faction))
	collision_mask = PHYSICS_LAYERS.get_bullet_hit_mask(int(faction))
