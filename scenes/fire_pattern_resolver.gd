extends RefCounted
class_name FirePatternResolver

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")

# 统一约定模式配置字段，避免 CombatManager 和解析器之间出现字符串漂移。
const CONFIG_FAN_BULLET_COUNT := "fan_bullet_count"
const CONFIG_FAN_TOTAL_ANGLE_DEG := "fan_total_angle_deg"
const CONFIG_RING_BULLET_COUNT := "ring_bullet_count"
const CONFIG_RING_ANGLE_OFFSET_DEG := "ring_angle_offset_deg"
const CONFIG_RANDOM_BULLET_COUNT := "random_bullet_count"
const CONFIG_RANDOM_HALF_ANGLE_DEG := "random_half_angle_deg"
const CONFIG_WAVE_BULLET_COUNT := "wave_bullet_count"
const CONFIG_WAVE_TOTAL_ANGLE_DEG := "wave_total_angle_deg"
const CONFIG_WAVE_AMPLITUDE_DEG := "wave_amplitude_deg"
const CONFIG_WAVE_FREQUENCY := "wave_frequency"
const CONFIG_SPIRAL_BULLET_COUNT := "spiral_bullet_count"
const CONFIG_SPIRAL_ANGLE_OFFSET_DEG := "spiral_angle_offset_deg"

static func build_shot_directions(base_direction: Vector2, fire_mode: int, config: Dictionary) -> Array[Vector2]:
	# 所有模式都基于单位方向计算；若外部意外传入零向量，则回退到向右发射。
	var normalized_direction := base_direction.normalized()
	if normalized_direction == Vector2.ZERO:
		normalized_direction = Vector2.RIGHT

	# 根据请求最终解析出的模式展开多方向结果。
	match fire_mode:
		SHARED_ENUMS.FireMode.FAN:
			return _build_fan_directions(normalized_direction, config)
		SHARED_ENUMS.FireMode.RING:
			return _build_ring_directions(normalized_direction, config)
		SHARED_ENUMS.FireMode.RANDOM_SCATTER:
			return _build_random_scatter_directions(normalized_direction, config)
		SHARED_ENUMS.FireMode.WAVE:
			return _build_wave_directions(normalized_direction, config)
		SHARED_ENUMS.FireMode.SPIRAL:
			return _build_spiral_directions(normalized_direction, config)
		_:
			return _build_single_directions(normalized_direction)

static func _build_single_directions(base_direction: Vector2) -> Array[Vector2]:
	# 单发模式只保留基础朝向本身。
	return [base_direction]

static func _build_fan_directions(base_direction: Vector2, config: Dictionary) -> Array[Vector2]:
	# 扇形模式复用均匀分布函数，在总张角内展开多颗子弹。
	return _build_even_spread_directions(
		base_direction,
		int(config.get(CONFIG_FAN_BULLET_COUNT, 1)),
		float(config.get(CONFIG_FAN_TOTAL_ANGLE_DEG, 0.0))
	)

static func _build_ring_directions(base_direction: Vector2, config: Dictionary) -> Array[Vector2]:
	# 环形模式围绕完整 360 度等分方向。
	var directions: Array[Vector2] = []
	var count: int = max(int(config.get(CONFIG_RING_BULLET_COUNT, 1)), 1)
	var step_angle: float = 360.0 / float(count)
	var angle_offset_deg: float = float(config.get(CONFIG_RING_ANGLE_OFFSET_DEG, 0.0))

	for index in count:
		var angle_deg: float = angle_offset_deg + step_angle * index
		directions.append(_rotate_direction(base_direction, angle_deg))

	return directions

static func _build_random_scatter_directions(base_direction: Vector2, config: Dictionary) -> Array[Vector2]:
	# 随机散射模式在基础朝向两侧随机偏转，让每次开火都有离散感。
	var directions: Array[Vector2] = []
	var count: int = max(int(config.get(CONFIG_RANDOM_BULLET_COUNT, 1)), 1)
	var half_angle_deg: float = float(config.get(CONFIG_RANDOM_HALF_ANGLE_DEG, 0.0))

	for _index in count:
		var angle_deg: float = randf_range(-half_angle_deg, half_angle_deg)
		directions.append(_rotate_direction(base_direction, angle_deg))

	return directions

static func _build_wave_directions(base_direction: Vector2, config: Dictionary) -> Array[Vector2]:
	# 波浪模式先按扇形铺开，再对每颗子弹追加正弦角度偏移，形成起伏排列。
	var directions: Array[Vector2] = []
	var count: int = max(int(config.get(CONFIG_WAVE_BULLET_COUNT, 1)), 1)
	if count == 1:
		return [base_direction]

	var total_angle_deg: float = float(config.get(CONFIG_WAVE_TOTAL_ANGLE_DEG, 0.0))
	var amplitude_deg: float = float(config.get(CONFIG_WAVE_AMPLITUDE_DEG, 0.0))
	var frequency: float = float(config.get(CONFIG_WAVE_FREQUENCY, 0.0))

	for index in count:
		var ratio: float = float(index) / float(count - 1)
		var base_offset: float = lerpf(-total_angle_deg * 0.5, total_angle_deg * 0.5, ratio)
		var wave_offset: float = sin(ratio * TAU * frequency) * amplitude_deg
		directions.append(_rotate_direction(base_direction, base_offset + wave_offset))

	return directions

static func _build_spiral_directions(base_direction: Vector2, config: Dictionary) -> Array[Vector2]:
	# 螺旋模式基于持续推进的全局角度生成方向，连续多次发射后会表现出旋转效果。
	var directions: Array[Vector2] = []
	var count: int = max(int(config.get(CONFIG_SPIRAL_BULLET_COUNT, 1)), 1)
	var spiral_angle_offset_deg: float = float(config.get(CONFIG_SPIRAL_ANGLE_OFFSET_DEG, 0.0))
	var spiral_state_angle_deg: float = float(config.get("spiral_state_angle_deg", 0.0))
	var base_angle_deg: float = spiral_angle_offset_deg + spiral_state_angle_deg
	if count == 1:
		return [_rotate_direction(base_direction, base_angle_deg)]
	if count == 2:
		return [
			_rotate_direction(base_direction, base_angle_deg),
			_rotate_direction(base_direction, base_angle_deg + 180.0),
		]

	var step_angle: float = 360.0 / float(count)
	for index in count:
		var angle_deg: float = base_angle_deg + step_angle * index
		directions.append(_rotate_direction(base_direction, angle_deg))

	return directions

static func _build_even_spread_directions(base_direction: Vector2, bullet_count: int, total_angle_deg: float) -> Array[Vector2]:
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

static func _rotate_direction(direction: Vector2, angle_deg: float) -> Vector2:
	# 对基础方向做角度旋转，并统一返回单位向量，避免不同模式产生速度差异。
	return direction.rotated(deg_to_rad(angle_deg)).normalized()
