extends Node

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")
const FIRE_PATTERN_RESOLVER = preload("res://scenes/fire_pattern_resolver.gd")

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
# 当前场景里的玩家节点暂时仍作为默认发射者接入点；后续怪物可直接调用 request_fire。
@onready var player = get_tree().current_scene.get_node("Entities/Player")

var current_spiral_angle_deg: float = 0.0

func _ready() -> void:
	# 现阶段仍监听玩家攻击信号，但真正的发射逻辑已经收口到 request_fire()。
	player.attack_performed.connect(_on_player_attack)

func _on_player_attack(muzzle_position: Vector2, direction: Vector2, selected_fire_mode: int) -> void:
	# 玩家信号只负责提供本次开火信息，再包装成统一发射请求交给管理器处理。
	request_fire(_build_fire_request(player, muzzle_position, direction, selected_fire_mode))

func request_fire(request: Dictionary) -> void:
	# 所有发射者最终都走这个入口，后续怪物、陷阱或技能节点也复用这条链路。
	var spawn_position: Vector2 = request.get(REQUEST_SPAWN_POSITION, Vector2.ZERO)
	var fire_mode := int(_resolve_fire_mode(request))
	var pattern_config := _build_pattern_config(fire_mode)
	for shot_direction in FIRE_PATTERN_RESOLVER.build_shot_directions(_get_request_direction(request), fire_mode, pattern_config):
		_spawn_bullet(request, spawn_position, shot_direction)
	if fire_mode == SHARED_ENUMS.FireMode.SPIRAL:
		current_spiral_angle_deg = fposmod(current_spiral_angle_deg + spiral_step_angle_deg, 360.0)

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

	for key in extra:
		request[key] = extra[key]

	return request

func _resolve_fire_mode(request: Dictionary) -> int:
	# 请求里显式指定的模式优先级最高；未指定时再回退到发射者默认模式。
	var selected_fire_mode: int = int(request.get(REQUEST_FIRE_MODE, -1))
	if selected_fire_mode >= SHARED_ENUMS.FireMode.SINGLE and selected_fire_mode <= SHARED_ENUMS.FireMode.SPIRAL:
		return selected_fire_mode

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

func _build_pattern_config(fire_mode: int) -> Dictionary:
	# 统一从 Inspector 导出的参数组装模式配置，交给独立解析器计算方向。
	return {
		FIRE_PATTERN_RESOLVER.CONFIG_FAN_BULLET_COUNT: fan_bullet_count,
		FIRE_PATTERN_RESOLVER.CONFIG_FAN_TOTAL_ANGLE_DEG: fan_total_angle_deg,
		FIRE_PATTERN_RESOLVER.CONFIG_RING_BULLET_COUNT: ring_bullet_count,
		FIRE_PATTERN_RESOLVER.CONFIG_RING_ANGLE_OFFSET_DEG: ring_angle_offset_deg,
		FIRE_PATTERN_RESOLVER.CONFIG_RANDOM_BULLET_COUNT: random_bullet_count,
		FIRE_PATTERN_RESOLVER.CONFIG_RANDOM_HALF_ANGLE_DEG: random_half_angle_deg,
		FIRE_PATTERN_RESOLVER.CONFIG_WAVE_BULLET_COUNT: wave_bullet_count,
		FIRE_PATTERN_RESOLVER.CONFIG_WAVE_TOTAL_ANGLE_DEG: wave_total_angle_deg,
		FIRE_PATTERN_RESOLVER.CONFIG_WAVE_AMPLITUDE_DEG: wave_amplitude_deg,
		FIRE_PATTERN_RESOLVER.CONFIG_WAVE_FREQUENCY: wave_frequency,
		FIRE_PATTERN_RESOLVER.CONFIG_SPIRAL_BULLET_COUNT: spiral_bullet_count,
		FIRE_PATTERN_RESOLVER.CONFIG_SPIRAL_ANGLE_OFFSET_DEG: spiral_angle_offset_deg,
		SPIRAL_STATE_ANGLE_DEG: _get_spiral_state_angle_deg(fire_mode),
	}

func _get_spiral_state_angle_deg(fire_mode: int) -> float:
	# 只有螺旋模式才使用持续推进的角度状态，其他模式统一视为 0。
	if fire_mode != SHARED_ENUMS.FireMode.SPIRAL:
		return 0.0

	return current_spiral_angle_deg

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

	return setup_data
