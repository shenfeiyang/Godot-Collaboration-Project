extends Node

# 统一定义当前项目可切换的几种发射模式，方便 Player、Enemy 和管理器共用同一套编号。
enum FireMode {
	SINGLE,
	FAN,
	RING,
	RANDOM_SCATTER,
	WAVE,
}

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

# 子弹场景资源，由场景面板指定具体要生成的子弹预制体。
@export var bullet_tscn: PackedScene
# 作为兜底配置使用的默认发射模式；当发射请求未提供模式时，回退到这里。
@export var current_fire_mode: FireMode = FireMode.SINGLE
# 扇形模式下生成的子弹数量。
@export_range(1, 32, 1) var fan_bullet_count: int = 5
# 扇形模式下整个扇面的总张角，单位为度。
@export_range(0.0, 360.0, 1.0) var fan_total_angle_deg: float = 60.0
# 环形模式下一圈生成的子弹数量。
@export_range(1, 64, 1) var ring_bullet_count: int = 8
# 环形模式整体额外旋转的角度，便于调节第一颗子弹的起始朝向。
@export_range(0.0, 360.0, 1.0) var ring_angle_offset_deg: float = 0.0
# 随机散射模式下一次生成的子弹数量。
@export_range(1, 32, 1) var random_bullet_count: int = 5
# 随机散射模式下，单颗子弹相对基础朝向允许偏转的半角范围。
@export_range(0.0, 180.0, 1.0) var random_half_angle_deg: float = 20.0
# 波浪模式下一次生成的子弹数量。
@export_range(1, 32, 1) var wave_bullet_count: int = 7
# 波浪模式基础分布覆盖的总角度范围，单位为度。
@export_range(0.0, 360.0, 1.0) var wave_total_angle_deg: float = 60.0
# 波浪模式在基础分布上叠加的波动振幅，单位为度。
@export_range(0.0, 180.0, 1.0) var wave_amplitude_deg: float = 10.0
# 波浪模式在整批子弹中的起伏频率。
@export_range(0.0, 8.0, 0.1) var wave_frequency: float = 1.0
# 子弹统一挂到独立容器下，避免和角色或地块节点混在一起。
@onready var bullet_container: Node2D = $"../BulletContainer"
# 当前场景里的玩家节点暂时仍作为默认发射者接入点；后续怪物可直接调用 request_fire。
@onready var player = get_tree().current_scene.get_node("Player")

func _ready() -> void:
	# 现阶段仍监听玩家攻击信号，但真正的发射逻辑已经收口到 request_fire()。
	player.attack_performed.connect(_on_player_attack)

func _on_player_attack(muzzle_position: Vector2, direction: Vector2, selected_fire_mode: int) -> void:
	# 玩家信号只负责提供本次开火信息，再包装成统一发射请求交给管理器处理。
	request_fire(_build_fire_request(player, muzzle_position, direction, selected_fire_mode))

func request_fire(request: Dictionary) -> void:
	# 所有发射者最终都走这个入口，后续怪物、陷阱或技能节点也复用这条链路。
	var spawn_position: Vector2 = request.get(REQUEST_SPAWN_POSITION, Vector2.ZERO)
	for shot_direction in _build_shot_directions(_get_request_direction(request), _resolve_fire_mode(request)):
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

	for key in extra:
		request[key] = extra[key]

	return request

func _build_shot_directions(base_direction: Vector2, fire_mode: FireMode) -> Array[Vector2]:
	# 所有模式都基于单位方向计算；若外部意外传入零向量，则回退到向右发射。
	var normalized_direction := base_direction.normalized()
	if normalized_direction == Vector2.ZERO:
		normalized_direction = Vector2.RIGHT

	# 根据请求最终解析出的模式展开多方向结果。
	match fire_mode:
		FireMode.FAN:
			return _build_fan_directions(normalized_direction)
		FireMode.RING:
			return _build_ring_directions(normalized_direction)
		FireMode.RANDOM_SCATTER:
			return _build_random_scatter_directions(normalized_direction)
		FireMode.WAVE:
			return _build_wave_directions(normalized_direction)
		_:
			return _build_single_directions(normalized_direction)

func _resolve_fire_mode(request: Dictionary) -> FireMode:
	# 请求里显式指定的模式优先级最高；未指定时再回退到发射者默认模式。
	var selected_fire_mode: int = int(request.get(REQUEST_FIRE_MODE, -1))
	if selected_fire_mode >= FireMode.SINGLE and selected_fire_mode <= FireMode.WAVE:
		return selected_fire_mode as FireMode

	return _get_source_fire_mode(request)

func _get_source_fire_mode(request: Dictionary) -> FireMode:
	# 发射者节点上导出的 fire_mode 作为主要数据源；若不存在该字段，再回退到管理器默认值。
	var source = request.get(REQUEST_SOURCE, null)
	if source != null and "fire_mode" in source:
		return source.fire_mode as FireMode

	return current_fire_mode

func _get_request_direction(request: Dictionary) -> Vector2:
	# 发射方向统一做一次标准化，避免不同调用方重复处理零向量兜底。
	var base_direction: Vector2 = request.get(REQUEST_DIRECTION, Vector2.RIGHT)
	var normalized_direction := base_direction.normalized()
	if normalized_direction == Vector2.ZERO:
		return Vector2.RIGHT

	return normalized_direction

func _build_single_directions(base_direction: Vector2) -> Array[Vector2]:
	# 单发模式只保留基础朝向本身。
	return [base_direction]

func _build_fan_directions(base_direction: Vector2) -> Array[Vector2]:
	# 扇形模式复用均匀分布函数，在总张角内展开多颗子弹。
	return _build_even_spread_directions(base_direction, fan_bullet_count, fan_total_angle_deg)

func _build_ring_directions(base_direction: Vector2) -> Array[Vector2]:
	# 环形模式围绕完整 360 度等分方向。
	var directions: Array[Vector2] = []
	var count: int = max(ring_bullet_count, 1)
	var step_angle: float = 360.0 / float(count)

	for index in count:
		var angle_deg: float = ring_angle_offset_deg + step_angle * index
		directions.append(_rotate_direction(base_direction, angle_deg))

	return directions

func _build_random_scatter_directions(base_direction: Vector2) -> Array[Vector2]:
	# 随机散射模式在基础朝向两侧随机偏转，让每次开火都有离散感。
	var directions: Array[Vector2] = []
	var count: int = max(random_bullet_count, 1)

	for _index in count:
		var angle_deg: float = randf_range(-random_half_angle_deg, random_half_angle_deg)
		directions.append(_rotate_direction(base_direction, angle_deg))

	return directions

func _build_wave_directions(base_direction: Vector2) -> Array[Vector2]:
	# 波浪模式先按扇形铺开，再对每颗子弹追加正弦角度偏移，形成起伏排列。
	var directions: Array[Vector2] = []
	var count: int = max(wave_bullet_count, 1)
	if count == 1:
		return [base_direction]

	for index in count:
		var ratio: float = float(index) / float(count - 1)
		var base_offset: float = lerpf(-wave_total_angle_deg * 0.5, wave_total_angle_deg * 0.5, ratio)
		var wave_offset: float = sin(ratio * TAU * wave_frequency) * wave_amplitude_deg
		directions.append(_rotate_direction(base_direction, base_offset + wave_offset))

	return directions

func _build_even_spread_directions(base_direction: Vector2, bullet_count: int, total_angle_deg: float) -> Array[Vector2]:
	# 通用均匀分布函数，给扇形等模式复用；数量为 1 时直接退化成单发。
	var directions: Array[Vector2] = []
	var count: int = max(bullet_count, 1)
	if count == 1:
		return [base_direction]

	var start_angle: float = -total_angle_deg * 0.5
	var step_angle: float = total_angle_deg / float(count - 1)
	for index in count:
		var angle_deg: float = start_angle + step_angle * index
		directions.append(_rotate_direction(base_direction, angle_deg))

	return directions

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

func _rotate_direction(direction: Vector2, angle_deg: float) -> Vector2:
	# 对基础方向做角度旋转，并统一返回单位向量，避免不同模式产生速度差异。
	return direction.rotated(deg_to_rad(angle_deg)).normalized()
