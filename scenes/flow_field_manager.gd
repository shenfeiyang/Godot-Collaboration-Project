extends Node
class_name FlowFieldManager

signal flow_field_rebuilt

const DIAGONAL_STEP_COST := 1.41421356
const NEIGHBOR_OFFSETS := [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]
const NEIGHBOR_STEP_COSTS := [
	1.0,
	1.0,
	1.0,
	1.0,
	DIAGONAL_STEP_COST,
	DIAGONAL_STEP_COST,
	DIAGONAL_STEP_COST,
	DIAGONAL_STEP_COST,
]

static var _debug_rebuild_total_usec: int = 0
static var _debug_rebuild_count: int = 0
static var _debug_last_rebuild_usec: int = 0
static var _debug_rebuild_total_frames: int = 0
static var _debug_last_rebuild_frames: int = 0

# 用于生成流场的 TileMapLayer 路径。
@export_group("节点引用")
@export var tile_map_path: NodePath
# 当前追踪目标玩家路径。
@export var player_path: NodePath

# 玩家跨格时才重建流场，避免静态目标下重复整图刷新。
@export_group("流场配置")
# 仅在目标附近的局部窗口内重建流场，降低整图扩散成本。
@export_range(8, 256, 1) var rebuild_radius_in_cells: int = 32
# 不可达或缺失方向时回退的默认方向。
@export var fallback_direction: Vector2 = Vector2.ZERO

var _tile_map: TileMapLayer = null
var _player: Node2D = null
var _last_target_cell: Vector2i = Vector2i(999999, 999999)
var _cost_field: Dictionary = {}
var _flow_field: Dictionary = {}
var _walkable_cells: Dictionary = {}
# 预缓存每个可走格子允许扩散的邻居索引，避免重建时重复做可走性判定。
var _cached_neighbor_indices: Dictionary = {}
var _neighbor_flow_directions: Array[Vector2] = []

func _ready() -> void:
	_tile_map = get_node_or_null(tile_map_path) as TileMapLayer
	_player = get_node_or_null(player_path) as Node2D
	_rebuild_neighbor_flow_directions()
	_rebuild_walkable_cells()
	_rebuild_cached_neighbors()
	_refresh_flow_field(true)

func _process(_delta: float) -> void:
	if _tile_map == null or _player == null:
		return
	if _world_to_cell(_player.global_position) == _last_target_cell:
		return

	_refresh_flow_field()

func get_flow_direction(world_position: Vector2) -> Vector2:
	if _tile_map == null or _tile_map.tile_set == null:
		return fallback_direction

	var local_position := _tile_map.to_local(world_position)
	var center_cell := _tile_map.local_to_map(local_position)
	var center_local := _tile_map.map_to_local(center_cell)
	var tile_size := Vector2(_tile_map.tile_set.tile_size)
	if tile_size.x <= 0.0 or tile_size.y <= 0.0:
		return _get_flow_direction_for_cell(center_cell)

	var offset := local_position - center_local
	var step_x := Vector2i.RIGHT if offset.x >= 0.0 else Vector2i.LEFT
	var step_y := Vector2i.DOWN if offset.y >= 0.0 else Vector2i.UP
	var tx: float = clamp(abs(offset.x) / max(tile_size.x * 0.5, 0.001), 0.0, 1.0)
	var ty: float = clamp(abs(offset.y) / max(tile_size.y * 0.5, 0.001), 0.0, 1.0)

	var weighted_direction := Vector2.ZERO
	var total_weight := 0.0
	var sample_result := _accumulate_flow_sample(center_cell, (1.0 - tx) * (1.0 - ty), weighted_direction, total_weight)
	weighted_direction = sample_result.direction
	total_weight = sample_result.total_weight
	sample_result = _accumulate_flow_sample(center_cell + step_x, tx * (1.0 - ty), weighted_direction, total_weight)
	weighted_direction = sample_result.direction
	total_weight = sample_result.total_weight
	sample_result = _accumulate_flow_sample(center_cell + step_y, (1.0 - tx) * ty, weighted_direction, total_weight)
	weighted_direction = sample_result.direction
	total_weight = sample_result.total_weight
	sample_result = _accumulate_flow_sample(center_cell + step_x + step_y, tx * ty, weighted_direction, total_weight)
	weighted_direction = sample_result.direction
	total_weight = sample_result.total_weight
	if total_weight <= 0.0:
		return fallback_direction

	var blended_direction := weighted_direction / total_weight
	return blended_direction.normalized() if blended_direction != Vector2.ZERO else Vector2.ZERO

func _refresh_flow_field(force: bool = false) -> void:
	if _tile_map == null or _player == null:
		return

	var target_cell := _world_to_cell(_player.global_position)
	if not force and target_cell == _last_target_cell:
		return

	_last_target_cell = target_cell
	var started_usec := Time.get_ticks_usec()
	_build_flow_field(target_cell)
	_debug_last_rebuild_usec = Time.get_ticks_usec() - started_usec
	_debug_rebuild_total_usec += _debug_last_rebuild_usec
	_debug_rebuild_count += 1
	_debug_last_rebuild_frames = 1
	_debug_rebuild_total_frames += 1
	flow_field_rebuilt.emit()

func _rebuild_walkable_cells() -> void:
	_walkable_cells.clear()
	if _tile_map == null:
		return

	for cell in _tile_map.get_used_cells():
		_walkable_cells[cell] = not _is_blocked_cell(cell)

func _rebuild_cached_neighbors() -> void:
	_cached_neighbor_indices.clear()
	for cell in _walkable_cells.keys():
		if not _walkable_cells[cell]:
			continue
		var neighbor_indices := PackedInt32Array()
		for index in range(NEIGHBOR_OFFSETS.size()):
			var neighbor: Vector2i = cell + NEIGHBOR_OFFSETS[index]
			if not _can_step_to(cell, neighbor):
				continue
			neighbor_indices.append(index)
		_cached_neighbor_indices[cell] = neighbor_indices

func _build_flow_field(target_cell: Vector2i) -> void:
	_cost_field.clear()
	_flow_field.clear()
	if not _walkable_cells.get(target_cell, false):
		return

	var frontier_cells: Array[Vector2i] = [target_cell]
	var frontier_costs: Array[float] = [0.0]
	_cost_field[target_cell] = 0.0
	_flow_field[target_cell] = Vector2.ZERO
	var radius := rebuild_radius_in_cells
	while not frontier_cells.is_empty():
		var current: Vector2i = frontier_cells[0]
		var current_cost: float = frontier_costs[0]
		_heap_remove_root(frontier_cells, frontier_costs)
		if current_cost > float(_cost_field.get(current, INF)):
			continue

		if not _cached_neighbor_indices.has(current):
			continue
		var neighbor_indices: PackedInt32Array = _cached_neighbor_indices[current]
		for index in neighbor_indices:
			var neighbor: Vector2i = current + NEIGHBOR_OFFSETS[index]
			if radius > 0 and (abs(neighbor.x - target_cell.x) > radius or abs(neighbor.y - target_cell.y) > radius):
				continue
			var next_cost := current_cost + float(NEIGHBOR_STEP_COSTS[index])
			if next_cost >= float(_cost_field.get(neighbor, INF)):
				continue
			_cost_field[neighbor] = next_cost
			_flow_field[neighbor] = -_neighbor_flow_directions[index]
			_heap_push(frontier_cells, frontier_costs, neighbor, next_cost)

func _can_step_to(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if not _walkable_cells.get(to_cell, false):
		return false

	var delta := to_cell - from_cell
	if abs(delta.x) != 1 or abs(delta.y) != 1:
		return true

	var horizontal_cell := from_cell + Vector2i(delta.x, 0)
	var vertical_cell := from_cell + Vector2i(0, delta.y)
	return _walkable_cells.get(horizontal_cell, false) and _walkable_cells.get(vertical_cell, false)

func _get_flow_direction_for_cell(cell: Vector2i) -> Vector2:
	if _flow_field.has(cell):
		return _flow_field[cell]

	return fallback_direction

func _accumulate_flow_sample(cell: Vector2i, weight: float, weighted_direction: Vector2, total_weight: float) -> Dictionary:
	if weight <= 0.0:
		return {
			"direction": weighted_direction,
			"total_weight": total_weight,
		}

	var sample_direction := _get_flow_direction_for_cell(cell)
	if sample_direction == Vector2.ZERO:
		return {
			"direction": weighted_direction,
			"total_weight": total_weight,
		}

	return {
		"direction": weighted_direction + sample_direction * weight,
		"total_weight": total_weight + weight,
	}

func get_debug_walkable_cells() -> Dictionary:
	return _walkable_cells.duplicate()

func get_debug_flow_field() -> Dictionary:
	return _flow_field.duplicate()

func get_debug_target_cell() -> Vector2i:
	return _last_target_cell

func get_debug_tile_map() -> TileMapLayer:
	return _tile_map

static func get_debug_rebuild_stats() -> Dictionary:
	var average_usec := 0.0
	var average_frames := 0.0
	if _debug_rebuild_count > 0:
		average_usec = float(_debug_rebuild_total_usec) / float(_debug_rebuild_count)
		average_frames = float(_debug_rebuild_total_frames) / float(_debug_rebuild_count)
	return {
		"last_usec": _debug_last_rebuild_usec,
		"average_usec": average_usec,
		"count": _debug_rebuild_count,
		"last_frames": _debug_last_rebuild_frames,
		"average_frames": average_frames,
	}

func is_rebuild_in_progress() -> bool:
	return false

func get_debug_build_target_cell() -> Vector2i:
	return _last_target_cell

func _world_to_cell(world_position: Vector2) -> Vector2i:
	return _tile_map.local_to_map(_tile_map.to_local(world_position))

func _cell_to_world(cell: Vector2i) -> Vector2:
	return _tile_map.to_global(_tile_map.map_to_local(cell))

func _is_blocked_cell(cell: Vector2i) -> bool:
	var tile_data := _tile_map.get_cell_tile_data(cell)
	if tile_data == null:
		return false

	return tile_data.get_collision_polygons_count(0) > 0

func _rebuild_neighbor_flow_directions() -> void:
	_neighbor_flow_directions.clear()
	if _tile_map == null:
		return

	var origin_world := _cell_to_world(Vector2i.ZERO)
	for direction in NEIGHBOR_OFFSETS:
		var world_offset := _cell_to_world(direction) - origin_world
		_neighbor_flow_directions.append(world_offset.normalized())

func _heap_push(cells: Array[Vector2i], costs: Array[float], cell: Vector2i, cost: float) -> void:
	cells.append(cell)
	costs.append(cost)
	var index := cells.size() - 1
	while index > 0:
		var parent_index := (index - 1) / 2
		if costs[parent_index] <= costs[index]:
			break
		_heap_swap(cells, costs, index, parent_index)
		index = parent_index

func _heap_remove_root(cells: Array[Vector2i], costs: Array[float]) -> void:
	var last_index := cells.size() - 1
	cells[0] = cells[last_index]
	costs[0] = costs[last_index]
	cells.remove_at(last_index)
	costs.remove_at(last_index)
	if cells.is_empty():
		return

	var index := 0
	while true:
		var left_index := index * 2 + 1
		if left_index >= cells.size():
			return
		var right_index := left_index + 1
		var smallest_index := left_index
		if right_index < cells.size() and costs[right_index] < costs[left_index]:
			smallest_index = right_index
		if costs[index] <= costs[smallest_index]:
			return
		_heap_swap(cells, costs, index, smallest_index)
		index = smallest_index

func _heap_swap(cells: Array[Vector2i], costs: Array[float], index_a: int, index_b: int) -> void:
	var cell := cells[index_a]
	cells[index_a] = cells[index_b]
	cells[index_b] = cell
	var cost := costs[index_a]
	costs[index_a] = costs[index_b]
	costs[index_b] = cost
