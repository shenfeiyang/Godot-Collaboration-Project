extends Node

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")
const FIRE_PATTERN_RESOLVER = preload("res://scenes/fire_pattern_resolver.gd")
const STAT_IDS = preload("res://scripts/stats/stat_ids.gd")
const SKILL_EXECUTION_CONTEXT_SCRIPT = preload("res://abilities/skills/runtime/skill_execution_context.gd")
const SKILL_RUNNER_SCRIPT = preload("res://abilities/skills/runtime/skill_runner.gd")

# 发射请求里约定使用的字段名，后续怪物或技能节点也按这套键名提交数据。
const REQUEST_SPAWN_POSITION := "spawn_position"
const REQUEST_DIRECTION := "direction"
const REQUEST_FIRE_MODE := "fire_mode"
const REQUEST_SOURCE := "source"
const REQUEST_FACTION := "faction"
const REQUEST_BULLET_SCENE := "bullet_scene"
const REQUEST_SPEED_OVERRIDE := "speed_override"
const REQUEST_DAMAGE := "damage"
const REQUEST_EXTRA := "extra"
const REQUEST_SPIRAL_BULLET_COUNT_OVERRIDE := "spiral_bullet_count_override"
const REQUEST_SPIRAL_STEP_ANGLE_DEG_OVERRIDE := "spiral_step_angle_deg_override"
const REQUEST_RING_BULLET_COUNT_OVERRIDE := "ring_bullet_count_override"
const REQUEST_RING_ANGLE_OFFSET_DEG_OVERRIDE := "ring_angle_offset_deg_override"
const REQUEST_PATTERN_CONFIG := "pattern_config"
const REQUEST_PATTERN_FIRE_MODE := "fire_mode"
const REQUEST_PATTERN_FAN_BULLET_COUNT := FIRE_PATTERN_RESOLVER.CONFIG_FAN_BULLET_COUNT
const REQUEST_PATTERN_FAN_TOTAL_ANGLE_DEG := FIRE_PATTERN_RESOLVER.CONFIG_FAN_TOTAL_ANGLE_DEG
const REQUEST_PATTERN_RING_BULLET_COUNT := FIRE_PATTERN_RESOLVER.CONFIG_RING_BULLET_COUNT
const REQUEST_PATTERN_RING_ANGLE_OFFSET_DEG := FIRE_PATTERN_RESOLVER.CONFIG_RING_ANGLE_OFFSET_DEG
const REQUEST_PATTERN_RANDOM_BULLET_COUNT := FIRE_PATTERN_RESOLVER.CONFIG_RANDOM_BULLET_COUNT
const REQUEST_PATTERN_RANDOM_HALF_ANGLE_DEG := FIRE_PATTERN_RESOLVER.CONFIG_RANDOM_HALF_ANGLE_DEG
const REQUEST_PATTERN_WAVE_BULLET_COUNT := FIRE_PATTERN_RESOLVER.CONFIG_WAVE_BULLET_COUNT
const REQUEST_PATTERN_WAVE_TOTAL_ANGLE_DEG := FIRE_PATTERN_RESOLVER.CONFIG_WAVE_TOTAL_ANGLE_DEG
const REQUEST_PATTERN_WAVE_AMPLITUDE_DEG := FIRE_PATTERN_RESOLVER.CONFIG_WAVE_AMPLITUDE_DEG
const REQUEST_PATTERN_WAVE_FREQUENCY := FIRE_PATTERN_RESOLVER.CONFIG_WAVE_FREQUENCY
const REQUEST_PATTERN_SPIRAL_BULLET_COUNT := FIRE_PATTERN_RESOLVER.CONFIG_SPIRAL_BULLET_COUNT
const REQUEST_PATTERN_SPIRAL_STEP_ANGLE_DEG := "spiral_step_angle_deg"
const REQUEST_PATTERN_SPIRAL_ANGLE_OFFSET_DEG := FIRE_PATTERN_RESOLVER.CONFIG_SPIRAL_ANGLE_OFFSET_DEG
const REQUEST_PATTERN_SPIRAL_STATE_ANGLE_DEG := "spiral_state_angle_deg"
const REQUEST_TRIGGER_SKILL_ID := "trigger_skill_id"
const HIT_DATA_TRIGGER_SKILL_ID := "hit_trigger_skill_id"

const SPIRAL_STATE_ANGLE_DEG := "spiral_state_angle_deg"

# 子弹场景资源，由场景面板指定具体要生成的子弹预制体。
@export_group("基础配置")
@export var bullet_tscn: PackedScene
# 作为兜底配置使用的默认发射模式；当发射请求未提供模式时，回退到这里。
@export_enum("单发", "扇形", "环形", "随机散射", "波浪", "螺旋") var current_fire_mode: int = SHARED_ENUMS.FireMode.SINGLE
# 扇形模式下生成的子弹数量。
@export_group("扇形模式")
@export_range(1, 32, 1) var fan_bullet_count: int = 5
# 扇形模式下整个扇面的总张角，单位为度。
@export_range(0.0, 360.0, 1.0) var fan_total_angle_deg: float = 60.0
# 环形模式下一圈生成的子弹数量。
@export_group("环形模式")
@export_range(1, 64, 1) var ring_bullet_count: int = 8
# 环形模式整体额外旋转的角度，便于调节第一颗子弹的起始朝向。
@export_range(0.0, 360.0, 1.0) var ring_angle_offset_deg: float = 0.0
# 随机散射模式下一次生成的子弹数量。
@export_group("随机散射模式")
@export_range(1, 32, 1) var random_bullet_count: int = 5
# 随机散射模式下，单颗子弹相对基础朝向允许偏转的半角范围。
@export_range(0.0, 180.0, 1.0) var random_half_angle_deg: float = 20.0
# 波浪模式下一次生成的子弹数量。
@export_group("波浪模式")
@export_range(1, 32, 1) var wave_bullet_count: int = 7
# 波浪模式基础分布覆盖的总角度范围，单位为度。
@export_range(0.0, 360.0, 1.0) var wave_total_angle_deg: float = 60.0
# 波浪模式在基础分布上叠加的波动振幅，单位为度。
@export_range(0.0, 180.0, 1.0) var wave_amplitude_deg: float = 10.0
# 波浪模式在整批子弹中的起伏频率。
@export_range(0.0, 8.0, 0.1) var wave_frequency: float = 1.0
# 螺旋模式下一次生成的子弹数量。
@export_group("螺旋模式")
@export_range(1, 16, 1) var spiral_bullet_count: int = 1
# 螺旋模式每次开火后推进的角度步进，单位为度。
@export_range(0.0, 360.0, 1.0) var spiral_step_angle_deg: float = 18.0
# 螺旋模式初始附加角度，便于整体旋转起始方向。
@export_range(0.0, 360.0, 1.0) var spiral_angle_offset_deg: float = 0.0
# 子弹统一挂到独立容器下，避免和角色或地块节点混在一起。
@onready var bullet_container: Node2D = $"../Entities/BulletContainer"

func request_fire(request: Dictionary) -> void:
	# 所有发射者最终都走这个入口，后续怪物、陷阱或技能节点也复用这条链路。
	var spawn_position: Vector2 = request.get(REQUEST_SPAWN_POSITION, Vector2.ZERO)
	var fire_mode := int(_resolve_fire_mode(request))
	var pattern_config := _build_pattern_config(request, fire_mode)
	for shot_direction in FIRE_PATTERN_RESOLVER.build_shot_directions(_get_request_direction(request), fire_mode, pattern_config):
		_spawn_bullet(request, spawn_position, shot_direction)

func request_fire_from_source(source: Node, spawn_position: Vector2, direction: Vector2, selected_fire_mode: int = -1, extra: Dictionary = {}) -> void:
	# 给未来的怪物或其他发射者预留一个更直接的调用入口，避免都自己手拼请求字典。
	request_fire(_build_fire_request(source, spawn_position, direction, selected_fire_mode, extra))

func _build_fire_request(source: Node, spawn_position: Vector2, direction: Vector2, selected_fire_mode: int = -1, extra: Dictionary = {}) -> Dictionary:
	# 先收口当前发射必须字段，再把额外覆盖项合并进来，便于后续逐步扩展。
	var request: Dictionary = {
		REQUEST_SPAWN_POSITION: spawn_position,
		REQUEST_DIRECTION: direction,
		REQUEST_FIRE_MODE: selected_fire_mode,
		REQUEST_SOURCE: source,
	}

	if source != null and "faction" in source:
		request[REQUEST_FACTION] = int(source.faction)

	if source is Node:
		var source_stats: StatsComponent = source.get_node_or_null("StatsComponent") as StatsComponent
		if source_stats != null:
			request[REQUEST_DAMAGE] = source_stats.get_stat(STAT_IDS.ATTACK)

	for key in extra:
		request[key] = extra[key]

	return request

func _resolve_fire_mode(request: Dictionary) -> int:
	# 请求里显式指定的模式优先级最高；未指定时再回退到发射者默认模式。
	var selected_fire_mode: int = int(request.get(REQUEST_FIRE_MODE, -1))
	if selected_fire_mode >= SHARED_ENUMS.FireMode.SINGLE and selected_fire_mode <= SHARED_ENUMS.FireMode.SPIRAL:
		return selected_fire_mode
	if request.has(REQUEST_PATTERN_CONFIG):
		var pattern_config: Dictionary = request.get(REQUEST_PATTERN_CONFIG, {})
		var pattern_fire_mode: int = int(pattern_config.get(REQUEST_PATTERN_FIRE_MODE, -1))
		if pattern_fire_mode >= SHARED_ENUMS.FireMode.SINGLE and pattern_fire_mode <= SHARED_ENUMS.FireMode.SPIRAL:
			return pattern_fire_mode

	return _get_source_fire_mode(request)

func _get_source_fire_mode(request: Dictionary) -> int:
	# 发射者节点上导出的 fire_mode 作为主要数据源；若不存在该字段，再回退到管理器默认值。
	var source = request.get(REQUEST_SOURCE, null)
	if source != null and "fire_mode" in source:
		return int(source.fire_mode)

	return current_fire_mode

func _get_request_direction(request: Dictionary) -> Vector2:
	# 发射方向统一做一次标准化，避免不同调用方重复处理零向量兜底。
	var base_direction: Vector2 = request.get(REQUEST_DIRECTION, Vector2.RIGHT)
	var normalized_direction := base_direction.normalized()
	if normalized_direction == Vector2.ZERO:
		return Vector2.RIGHT

	return normalized_direction

func _build_pattern_config(request: Dictionary, fire_mode: int) -> Dictionary:
	# 优先读取技能请求自带的模式配置；未覆盖时再回退到场景默认值。
	var request_pattern_config: Dictionary = request.get(REQUEST_PATTERN_CONFIG, {})
	return {
		FIRE_PATTERN_RESOLVER.CONFIG_FAN_BULLET_COUNT: int(request_pattern_config.get(REQUEST_PATTERN_FAN_BULLET_COUNT, fan_bullet_count)),
		FIRE_PATTERN_RESOLVER.CONFIG_FAN_TOTAL_ANGLE_DEG: float(request_pattern_config.get(REQUEST_PATTERN_FAN_TOTAL_ANGLE_DEG, fan_total_angle_deg)),
		FIRE_PATTERN_RESOLVER.CONFIG_RING_BULLET_COUNT: _get_ring_bullet_count(request, request_pattern_config),
		FIRE_PATTERN_RESOLVER.CONFIG_RING_ANGLE_OFFSET_DEG: _get_ring_angle_offset_deg(request, request_pattern_config),
		FIRE_PATTERN_RESOLVER.CONFIG_RANDOM_BULLET_COUNT: int(request_pattern_config.get(REQUEST_PATTERN_RANDOM_BULLET_COUNT, random_bullet_count)),
		FIRE_PATTERN_RESOLVER.CONFIG_RANDOM_HALF_ANGLE_DEG: float(request_pattern_config.get(REQUEST_PATTERN_RANDOM_HALF_ANGLE_DEG, random_half_angle_deg)),
		FIRE_PATTERN_RESOLVER.CONFIG_WAVE_BULLET_COUNT: int(request_pattern_config.get(REQUEST_PATTERN_WAVE_BULLET_COUNT, wave_bullet_count)),
		FIRE_PATTERN_RESOLVER.CONFIG_WAVE_TOTAL_ANGLE_DEG: float(request_pattern_config.get(REQUEST_PATTERN_WAVE_TOTAL_ANGLE_DEG, wave_total_angle_deg)),
		FIRE_PATTERN_RESOLVER.CONFIG_WAVE_AMPLITUDE_DEG: float(request_pattern_config.get(REQUEST_PATTERN_WAVE_AMPLITUDE_DEG, wave_amplitude_deg)),
		FIRE_PATTERN_RESOLVER.CONFIG_WAVE_FREQUENCY: float(request_pattern_config.get(REQUEST_PATTERN_WAVE_FREQUENCY, wave_frequency)),
		FIRE_PATTERN_RESOLVER.CONFIG_SPIRAL_BULLET_COUNT: _get_spiral_bullet_count(request, request_pattern_config),
		FIRE_PATTERN_RESOLVER.CONFIG_SPIRAL_ANGLE_OFFSET_DEG: float(request_pattern_config.get(REQUEST_PATTERN_SPIRAL_ANGLE_OFFSET_DEG, spiral_angle_offset_deg)),
		SPIRAL_STATE_ANGLE_DEG: _get_spiral_state_angle_deg(request, fire_mode, request_pattern_config),
	}

func _get_spiral_state_angle_deg(_request: Dictionary, fire_mode: int, request_pattern_config: Dictionary) -> float:
	# 螺旋角度状态优先使用技能运行时传入的值；未提供时再回退到场景默认行为。
	if fire_mode != SHARED_ENUMS.FireMode.SPIRAL:
		return 0.0
	return float(request_pattern_config.get(REQUEST_PATTERN_SPIRAL_STATE_ANGLE_DEG, 0.0))

func _get_spiral_bullet_count(request: Dictionary, request_pattern_config: Dictionary) -> int:
	var pattern_value: int = int(request_pattern_config.get(REQUEST_PATTERN_SPIRAL_BULLET_COUNT, spiral_bullet_count))
	var override_value: int = int(request.get(REQUEST_SPIRAL_BULLET_COUNT_OVERRIDE, pattern_value))
	return max(override_value, 1)

func _get_ring_bullet_count(request: Dictionary, request_pattern_config: Dictionary) -> int:
	var pattern_value: int = int(request_pattern_config.get(REQUEST_PATTERN_RING_BULLET_COUNT, ring_bullet_count))
	var override_value: int = int(request.get(REQUEST_RING_BULLET_COUNT_OVERRIDE, pattern_value))
	return max(override_value, 1)

func _get_ring_angle_offset_deg(request: Dictionary, request_pattern_config: Dictionary) -> float:
	var pattern_value: float = float(request_pattern_config.get(REQUEST_PATTERN_RING_ANGLE_OFFSET_DEG, ring_angle_offset_deg))
	return float(request.get(REQUEST_RING_ANGLE_OFFSET_DEG_OVERRIDE, pattern_value))

func _spawn_bullet(request: Dictionary, spawn_position: Vector2, shot_direction: Vector2) -> void:
	# 所有子弹都通过统一入口实例化，后续接对象池时只需要替换这一层。
	var bullet_scene := _get_request_bullet_scene(request)
	if bullet_scene == null:
		return

	var bullet = bullet_scene.instantiate()
	bullet.global_position = spawn_position
	bullet.setup(
		shot_direction,
		_get_request_source(request),
		_get_request_faction(request),
		_build_bullet_setup_data(request)
	)
	if bullet.has_signal("hit_registered") and not bullet.hit_registered.is_connected(_on_bullet_hit_registered):
		bullet.hit_registered.connect(_on_bullet_hit_registered)
	bullet_container.add_child(bullet)

func _get_request_source(request: Dictionary) -> Node:
	# 发射者节点原样透传给子弹，方便后面继续做归属过滤或命中归因。
	return request.get(REQUEST_SOURCE, null)

func _get_request_faction(request: Dictionary) -> int:
	# 先使用请求里显式传入的阵营；未提供时再尝试从发射者节点读取。
	if request.has(REQUEST_FACTION):
		return int(request[REQUEST_FACTION])

	var source = _get_request_source(request)
	if source != null and "faction" in source:
		return int(source.faction)

	return 0

func _get_request_bullet_scene(request: Dictionary) -> PackedScene:
	# 发射请求可按需覆盖子弹场景；未覆盖时继续走场景里默认配置。
	var requested_bullet_scene = request.get(REQUEST_BULLET_SCENE, null)
	if requested_bullet_scene is PackedScene:
		return requested_bullet_scene

	return bullet_tscn

func _build_bullet_setup_data(request: Dictionary) -> Dictionary:
	# 只把真正属于单颗子弹初始化的数据下发，避免把整条请求都塞进 Bullet。
	var setup_data: Dictionary = {}
	if request.has(REQUEST_SPEED_OVERRIDE):
		setup_data[REQUEST_SPEED_OVERRIDE] = float(request[REQUEST_SPEED_OVERRIDE])
	if request.has(REQUEST_DAMAGE):
		setup_data[REQUEST_DAMAGE] = request[REQUEST_DAMAGE]
	if request.has(REQUEST_EXTRA):
		setup_data[REQUEST_EXTRA] = request[REQUEST_EXTRA]
	if request.has(REQUEST_TRIGGER_SKILL_ID):
		setup_data[REQUEST_TRIGGER_SKILL_ID] = request[REQUEST_TRIGGER_SKILL_ID]

	return setup_data

func _on_bullet_hit_registered(hit_data: Dictionary) -> void:
	var target = hit_data.get("target", null)
	if target == null or not target is Node:
		return
	var stats_component: StatsComponent = target.get_node_or_null("StatsComponent") as StatsComponent
	if stats_component == null:
		return

	var source = hit_data.get("source", null)
	var attack_value: float = 0.0
	if source is Node:
		var source_stats: StatsComponent = source.get_node_or_null("StatsComponent") as StatsComponent
		if source_stats != null:
			attack_value = source_stats.get_stat(STAT_IDS.ATTACK)

	var damage_value: float = hit_data.get(REQUEST_DAMAGE, 0.0)
	stats_component.apply_damage({
		"source": source,
		"damage": damage_value,
		"attack": attack_value,
		"position": hit_data.get("position", Vector2.ZERO),
		"direction": hit_data.get("direction", Vector2.ZERO),
		"extra": hit_data.get(REQUEST_EXTRA, {}),
	})

	# ── Trigger 触发：命中后施放子技能 ──
	var trigger_skill_id: String = hit_data.get(HIT_DATA_TRIGGER_SKILL_ID, "")
	if trigger_skill_id.is_empty():
		return
	var trigger_skill_path := "res://abilities/skills/generated/%s.tres" % trigger_skill_id
	var trigger_def: SkillDefinition = load(trigger_skill_path) if ResourceLoader.exists(trigger_skill_path) else null
	if trigger_def == null:
		return
	# 创建临时 runner 执行子技能
	var context := SkillExecutionContext.new()
	context.caster = source
	context.combat_manager = self
	context.spawn_position = hit_data.get("position", Vector2.ZERO)
	context.facing_direction = hit_data.get("direction", Vector2.RIGHT)
	context.faction = int(hit_data.get("faction", 0))
	var runner: SkillRunner
	if trigger_def.runner_script != null:
		runner = trigger_def.runner_script.new() as SkillRunner
	else:
		runner = SKILL_RUNNER_SCRIPT.new()
	if runner == null:
		return
	runner.setup(trigger_def)
	runner.cast(context)
