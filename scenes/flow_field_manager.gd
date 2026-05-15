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
static var _debug_last_processed_cells: int = 0
static var _debug_total_processed_cells: int = 0
static var _debug_threshold_blocked_count: int = 0
static var _debug_threshold_committed_count: int = 0
static var _debug_last_unwalkable_target_cell: Vector2i = Vector2i(999999, 999999)

# 用于生成流场的 TileMapLayer 路径。
@export_group("节点引用")
@export var tile_map_path: NodePath
# 当前追踪目标玩家路径。
@export var player_path: NodePath

# 玩家跨格时才重建流场，避免静态目标下重复整图刷新。
@export_group("流场配置")
# 仅在目标附近的局部窗口内重建流场，降低整图扩散成本。
@export_range(8, 256, 1) var rebuild_radius_in_cells: int = 32
# 玩家连续跨格时，合并普通重建请求，避免短时间内重复整图刷新。
@export_range(0.0, 0.3, 0.01) var player_rebuild_debounce: float = 0.08
# 玩家进入新格后，需要再向格内推进多少，才提交新的流场目标格。
@export_range(0.0, 0.5, 0.01) var target_cell_commit_ratio: float = 0.4
# 单帧最多推进多少个 frontier 节点，避免整次构建压在一个 frame 里。
@export_range(8, 4096, 8) var rebuild_nodes_per_frame: int = 192
# 单帧用于推进流场构建的最长预算（微秒）。
@export_range(200, 10000, 100) var rebuild_usec_budget: int = 2000
# 收到敌人的强制刷新请求后，最短等待多久再真正重建，避免同帧/连续帧重复整图刷新。
@export_range(0.0, 1.0, 0.01) var forced_refresh_debounce: float = 0.35
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
var _pending_target_cell: Vector2i = Vector2i.ZERO
var _has_pending_player_rebuild: bool = false
var _player_rebuild_wait_remaining: float = 0.0
var _pending_forced_refresh: bool = false
var _forced_refresh_wait_remaining: float = 0.0
var _pending_build_target_cell: Vector2i = Vector2i.ZERO
var _pending_cost_field: Dictionary = {}
var _pending_flow_field: Dictionary = {}
var _pending_frontier_cells: Array[Vector2i] = []
var _pending_frontier_costs: Array[float] = []
var _rebuild_in_progress: bool = false
var _pending_rebuild_frames: int = 0
var _pending_rebuild_started_usec: int = 0
var _pending_processed_cells: int = 0

func _ready() -> void:
	_tile_map = get_node_or_null(tile_map_path) as TileMapLayer
	_player = get_node_or_null(player_path) as Node2D
	_rebuild_neighbor_flow_directions()
	_rebuild_walkable_cells()
	_rebuild_cached_neighbors()
	_refresh_flow_field(true)
	while _rebuild_in_progress:
		_step_flow_field_rebuild()

func _process(delta: float) -> void:
	if _tile_map == null or _player == null:
		return

	if _pending_forced_refresh:
		_forced_refresh_wait_remaining = max(_forced_refresh_wait_remaining - delta, 0.0)
		if _forced_refresh_wait_remaining <= 0.0:
			_pending_forced_refresh = false
			_refresh_flow_field(true)

	var player_position: Vector2 = _player.global_position
	var player_cell: Vector2i = _world_to_cell(player_position)
	var reference_cell: Vector2i = _get_rebuild_reference_cell()
	if player_cell == reference_cell:
		_clear_pending_player_rebuild()
	elif _should_commit_target_cell(player_position, player_cell):
		if not _has_pending_player_rebuild or _pending_target_cell != player_cell:
			_pending_target_cell = player_cell
			_has_pending_player_rebuild = true
			_player_rebuild_wait_remaining = player_rebuild_debounce
			_debug_threshold_committed_count += 1
	else:
		_debug_threshold_blocked_count += 1

	if _has_pending_player_rebuild:
		if _player_rebuild_wait_remaining > 0.0:
			_player_rebuild_wait_remaining = max(_player_rebuild_wait_remaining - delta, 0.0)
		if _player_rebuild_wait_remaining <= 0.0:
			_refresh_flow_field()

	if _rebuild_in_progress:
		_step_flow_field_rebuild()

func request_forced_refresh() -> void:
	_pending_forced_refresh = true
	if _forced_refresh_wait_remaining <= 0.0:
		_forced_refresh_wait_remaining = forced_refresh_debounce

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

	var target_cell: Vector2i = _world_to_cell(_player.global_position)
	if not force and _has_pending_player_rebuild:
		target_cell = _pending_target_cell

	if _rebuild_in_progress and target_cell == _pending_build_target_cell:
		_clear_pending_player_rebuild()
		return
	if not force and not _rebuild_in_progress and target_cell == _last_target_cell:
		_clear_pending_player_rebuild()
		return

	_clear_pending_player_rebuild()
	_begin_flow_field_rebuild(target_cell)

func _begin_flow_field_rebuild(target_cell: Vector2i) -> void:
	_discard_pending_build()
	if not _walkable_cells.get(target_cell, false):
		_debug_last_unwalkable_target_cell = target_cell
		return
	_pending_build_target_cell = target_cell
	_pending_cost_field = {}
	_pending_flow_field = {}
	_pending_frontier_cells = []
	_pending_frontier_costs = []
	_rebuild_in_progress = true
	_pending_rebuild_frames = 0
	_pending_rebuild_started_usec = Time.get_ticks_usec()
	_pending_processed_cells = 0
	_debug_last_unwalkable_target_cell = Vector2i(999999, 999999)

	_pending_cost_field[target_cell] = 0.0
	_pending_flow_field[target_cell] = Vector2.ZERO
	_pending_frontier_cells.append(target_cell)
	_pending_frontier_costs.append(0.0)

func _step_flow_field_rebuild() -> void:
	if not _rebuild_in_progress:
		return

	_pending_rebuild_frames += 1
	var frame_started_usec := Time.get_ticks_usec()
	var processed_this_frame: int = 0
	var radius := rebuild_radius_in_cells
	while not _pending_frontier_cells.is_empty():
		var current: Vector2i = _pending_frontier_cells[0]
		var current_cost: float = _pending_frontier_costs[0]
		_heap_remove_root(_pending_frontier_cells, _pending_frontier_costs)
		processed_this_frame += 1
		_pending_processed_cells += 1
		if current_cost > float(_pending_cost_field.get(current, INF)):
			if _rebuild_budget_reached(frame_started_usec, processed_this_frame):
				break
			continue

		if not _cached_neighbor_indices.has(current):
			if _rebuild_budget_reached(frame_started_usec, processed_this_frame):
				break
			continue

		var neighbor_indices: PackedInt32Array = _cached_neighbor_indices[current]
		for index in neighbor_indices:
			var neighbor: Vector2i = current + NEIGHBOR_OFFSETS[index]
			if radius > 0 and (abs(neighbor.x - _pending_build_target_cell.x) > radius or abs(neighbor.y - _pending_build_target_cell.y) > radius):
				continue
			var next_cost := current_cost + float(NEIGHBOR_STEP_COSTS[index])
			if next_cost >= float(_pending_cost_field.get(neighbor, INF)):
				continue
			_pending_cost_field[neighbor] = next_cost
			_pending_flow_field[neighbor] = -_neighbor_flow_directions[index]
			_heap_push(_pending_frontier_cells, _pending_frontier_costs, neighbor, next_cost)

		if _rebuild_budget_reached(frame_started_usec, processed_this_frame):
			break

	if _pending_frontier_cells.is_empty():
		_finish_flow_field_rebuild()

func _finish_flow_field_rebuild() -> void:
	_cost_field = _pending_cost_field
	_flow_field = _pending_flow_field
	_last_target_cell = _pending_build_target_cell
	_debug_last_rebuild_usec = Time.get_ticks_usec() - _pending_rebuild_started_usec
	_debug_rebuild_total_usec += _debug_last_rebuild_usec
	_debug_rebuild_count += 1
	_debug_last_rebuild_frames = _pending_rebuild_frames
	_debug_rebuild_total_frames += _pending_rebuild_frames
	_debug_last_processed_cells = _pending_processed_cells
	_debug_total_processed_cells += _pending_processed_cells
	_discard_pending_build()
	flow_field_rebuilt.emit()

func _discard_pending_build() -> void:
	_rebuild_in_progress = false
	_pending_build_target_cell = Vector2i.ZERO
	_pending_cost_field = {}
	_pending_flow_field = {}
	_pending_frontier_cells = []
	_pending_frontier_costs = []
	_pending_rebuild_frames = 0
	_pending_rebuild_started_usec = 0
	_pending_processed_cells = 0

func _rebuild_budget_reached(frame_started_usec: int, processed_this_frame: int) -> bool:
	if processed_this_frame >= rebuild_nodes_per_frame:
		return true
	if rebuild_usec_budget > 0 and Time.get_ticks_usec() - frame_started_usec >= rebuild_usec_budget:
		return true
	return false

func _clear_pending_player_rebuild() -> void:
	_has_pending_player_rebuild = false
	_pending_target_cell = Vector2i.ZERO
	_player_rebuild_wait_remaining = 0.0

func _get_rebuild_reference_cell() -> Vector2i:
	if _rebuild_in_progress:
		return _pending_build_target_cell
	return _last_target_cell

func _should_commit_target_cell(player_world_position: Vector2, candidate_cell: Vector2i) -> bool:
	if target_cell_commit_ratio <= 0.0:
		return true
	if _tile_map == null or _tile_map.tile_set == null:
		return true

	var reference_cell: Vector2i = _get_rebuild_reference_cell()
	var previous_center: Vector2 = _cell_to_world(reference_cell)
	var candidate_center: Vector2 = _cell_to_world(candidate_cell)
	var delta: Vector2i = candidate_cell - reference_cell
	var tile_size := Vector2(_tile_map.tile_set.tile_size)
	if tile_size.x <= 0.0 or tile_size.y <= 0.0:
		return true

	var candidate_offset: Vector2 = player_world_position - candidate_center
	var threshold_x: float = tile_size.x * 0.5 * target_cell_commit_ratio
	var threshold_y: float = tile_size.y * 0.5 * target_cell_commit_ratio
	if delta.x > 0 and player_world_position.x < candidate_center.x - threshold_x:
		return false
	if delta.x < 0 and player_world_position.x > candidate_center.x + threshold_x:
		return false
	if delta.y > 0 and player_world_position.y < candidate_center.y - threshold_y:
		return false
	if delta.y < 0 and player_world_position.y > candidate_center.y + threshold_y:
		return false
	if delta.x == 0 and abs(candidate_offset.x) > tile_size.x * 0.5:
		return false
	if delta.y == 0 and abs(candidate_offset.y) > tile_size.y * 0.5:
		return false

	return previous_center != candidate_center

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
	var average_processed_cells := 0.0
	if _debug_rebuild_count > 0:
		average_usec = float(_debug_rebuild_total_usec) / float(_debug_rebuild_count)
		average_frames = float(_debug_rebuild_total_frames) / float(_debug_rebuild_count)
		average_processed_cells = float(_debug_total_processed_cells) / float(_debug_rebuild_count)
	return {
		"last_usec": _debug_last_rebuild_usec,
		"average_usec": average_usec,
		"count": _debug_rebuild_count,
		"last_frames": _debug_last_rebuild_frames,
		"average_frames": average_frames,
		"last_processed_cells": _debug_last_processed_cells,
		"average_processed_cells": average_processed_cells,
		"threshold_blocked_count": _debug_threshold_blocked_count,
		"threshold_committed_count": _debug_threshold_committed_count,
		"last_unwalkable_target_cell": _debug_last_unwalkable_target_cell,
	}

func is_rebuild_in_progress() -> bool:
	return _rebuild_in_progress

func get_debug_build_target_cell() -> Vector2i:
	return _pending_build_target_cell if _rebuild_in_progress else _last_target_cell

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
