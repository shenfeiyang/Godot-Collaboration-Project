extends Node
class_name GridNavigationService

signal navigation_grid_rebuilt

const INVALID_CELL: Vector2i = Vector2i(999999, 999999)
const DIAGONAL_STEP_COST: float = 1.41421356
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]
const NEIGHBOR_STEP_COSTS: Array[float] = [
	1.0,
	1.0,
	1.0,
	1.0,
	DIAGONAL_STEP_COST,
	DIAGONAL_STEP_COST,
	DIAGONAL_STEP_COST,
	DIAGONAL_STEP_COST,
]

static var _debug_path_total_usec: int = 0
static var _debug_path_request_count: int = 0
static var _debug_path_cache_hit_count: int = 0
static var _debug_last_path_usec: int = 0
static var _debug_last_path_length: int = 0

# 读取地面碰撞网格的 TileMapLayer 路径。
@export_group("节点引用")
@export var tile_map_path: NodePath

# 寻路缓存保留条数上限。
@export_group("网格导航")
@export_range(0, 512, 1) var max_cached_paths: int = 128
# 目标格不可走时，向外搜索最近可走格的最大半径。
@export_range(0, 32, 1) var nearest_walkable_search_radius: int = 8
# 不可达时是否允许返回部分路径。
@export var allow_partial_path: bool = true

var _tile_map: TileMapLayer = null
var _walkable_cells: Dictionary = {}
var _cached_neighbor_indices: Dictionary = {}
var _path_cache: Dictionary = {}
var _path_cache_order: Array[String] = []

func _ready() -> void:
	_tile_map = get_node_or_null(tile_map_path) as TileMapLayer
	_rebuild_navigation_grid()

func _rebuild_navigation_grid() -> void:
	_rebuild_walkable_cells()
	_rebuild_cached_neighbors()
	_clear_path_cache()
	navigation_grid_rebuilt.emit()

func get_path_world(start_world: Vector2, target_world: Vector2) -> Array[Vector2]:
	if _tile_map == null:
		return []

	var started_usec: int = Time.get_ticks_usec()
	var start_cell: Vector2i = world_to_cell(start_world)
	var target_cell: Vector2i = world_to_cell(target_world)
	var path_cells: Array[Vector2i] = get_path_cells(start_cell, target_cell)
	_debug_last_path_usec = Time.get_ticks_usec() - started_usec
	_debug_path_total_usec += _debug_last_path_usec
	_debug_path_request_count += 1
	_debug_last_path_length = path_cells.size()
	if path_cells.is_empty():
		return []

	var path_world: Array[Vector2] = []
	for index in range(path_cells.size()):
		if index == 0 and path_cells[index] == start_cell:
			continue
		path_world.append(cell_to_world(path_cells[index]))
	return path_world

func get_path_cells(start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	var resolved_start: Vector2i = _resolve_path_cell(start_cell)
	var resolved_target: Vector2i = _resolve_path_cell(target_cell)
	if resolved_start == INVALID_CELL or resolved_target == INVALID_CELL:
		return []
	if resolved_start == resolved_target:
		return [resolved_start]

	var cache_key: String = _make_path_cache_key(resolved_start, resolved_target)
	if _path_cache.has(cache_key):
		_debug_path_cache_hit_count += 1
		return (_path_cache[cache_key] as Array[Vector2i]).duplicate()

	var path: Array[Vector2i] = _build_cell_path(resolved_start, resolved_target)
	if not path.is_empty():
		_store_path_cache(cache_key, path)
	return path

func world_to_cell(world_position: Vector2) -> Vector2i:
	if _tile_map == null:
		return INVALID_CELL
	return _tile_map.local_to_map(_tile_map.to_local(world_position))

func cell_to_world(cell: Vector2i) -> Vector2:
	if _tile_map == null:
		return Vector2.ZERO
	return _tile_map.to_global(_tile_map.map_to_local(cell))

func is_walkable_cell(cell: Vector2i) -> bool:
	return _walkable_cells.get(cell, false)

func get_debug_walkable_cells() -> Dictionary:
	return _walkable_cells.duplicate()

func get_debug_tile_map() -> TileMapLayer:
	return _tile_map

static func get_debug_path_stats() -> Dictionary:
	var average_usec: float = 0.0
	if _debug_path_request_count > 0:
		average_usec = float(_debug_path_total_usec) / float(_debug_path_request_count)
	return {
		"last_usec": _debug_last_path_usec,
		"average_usec": average_usec,
		"request_count": _debug_path_request_count,
		"cache_hit_count": _debug_path_cache_hit_count,
		"last_path_length": _debug_last_path_length,
	}

func _resolve_path_cell(cell: Vector2i) -> Vector2i:
	if is_walkable_cell(cell):
		return cell
	return _find_nearest_walkable_cell(cell)

func _find_nearest_walkable_cell(origin: Vector2i) -> Vector2i:
	if nearest_walkable_search_radius <= 0:
		return INVALID_CELL

	var best_cell: Vector2i = INVALID_CELL
	var best_distance: float = INF
	for radius in range(1, nearest_walkable_search_radius + 1):
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				var candidate: Vector2i = Vector2i(x, y)
				if not is_walkable_cell(candidate):
					continue
				var distance: float = origin.distance_squared_to(candidate)
				if distance >= best_distance:
					continue
				best_distance = distance
				best_cell = candidate
		if best_cell != INVALID_CELL:
			return best_cell

	return INVALID_CELL

func _build_cell_path(start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	var open_cells: Array[Vector2i] = []
	var open_priorities: Array[float] = []
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start_cell: 0.0}
	var best_cell: Vector2i = start_cell
	var best_heuristic: float = _estimate_remaining_cost(start_cell, target_cell)

	_heap_push(open_cells, open_priorities, start_cell, best_heuristic)
	while not open_cells.is_empty():
		var current: Vector2i = open_cells[0]
		_heap_remove_root(open_cells, open_priorities)
		if current == target_cell:
			return _reconstruct_path(came_from, current)

		var current_cost: float = float(g_score.get(current, INF))
		var current_heuristic: float = _estimate_remaining_cost(current, target_cell)
		if current_heuristic < best_heuristic:
			best_heuristic = current_heuristic
			best_cell = current

		var neighbor_indices: PackedInt32Array = _cached_neighbor_indices.get(current, PackedInt32Array())
		for index in neighbor_indices:
			var neighbor: Vector2i = current + NEIGHBOR_OFFSETS[index]
			var tentative_cost: float = current_cost + float(NEIGHBOR_STEP_COSTS[index])
			if tentative_cost >= float(g_score.get(neighbor, INF)):
				continue
			came_from[neighbor] = current
			g_score[neighbor] = tentative_cost
			var priority: float = tentative_cost + _estimate_remaining_cost(neighbor, target_cell)
			_heap_push(open_cells, open_priorities, neighbor, priority)

	if allow_partial_path and best_cell != start_cell:
		return _reconstruct_path(came_from, best_cell)
	return []

func _reconstruct_path(came_from: Dictionary, end_cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [end_cell]
	var current: Vector2i = end_cell
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path

func _estimate_remaining_cost(from_cell: Vector2i, to_cell: Vector2i) -> float:
	var dx: int = abs(from_cell.x - to_cell.x)
	var dy: int = abs(from_cell.y - to_cell.y)
	var diagonal_steps: int = min(dx, dy)
	var straight_steps: int = max(dx, dy) - diagonal_steps
	return float(diagonal_steps) * DIAGONAL_STEP_COST + float(straight_steps)

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
		var neighbor_indices: PackedInt32Array = PackedInt32Array()
		for index in range(NEIGHBOR_OFFSETS.size()):
			var neighbor: Vector2i = cell + NEIGHBOR_OFFSETS[index]
			if not _can_step_to(cell, neighbor):
				continue
			neighbor_indices.append(index)
		_cached_neighbor_indices[cell] = neighbor_indices

func _can_step_to(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if not _walkable_cells.get(to_cell, false):
		return false

	var delta: Vector2i = to_cell - from_cell
	if abs(delta.x) != 1 or abs(delta.y) != 1:
		return true

	var horizontal_cell: Vector2i = from_cell + Vector2i(delta.x, 0)
	var vertical_cell: Vector2i = from_cell + Vector2i(0, delta.y)
	return _walkable_cells.get(horizontal_cell, false) and _walkable_cells.get(vertical_cell, false)

func _is_blocked_cell(cell: Vector2i) -> bool:
	var tile_data: TileData = _tile_map.get_cell_tile_data(cell)
	if tile_data == null:
		return false
	return tile_data.get_collision_polygons_count(0) > 0

func _make_path_cache_key(start_cell: Vector2i, target_cell: Vector2i) -> String:
	return "%s,%s:%s,%s" % [start_cell.x, start_cell.y, target_cell.x, target_cell.y]

func _store_path_cache(cache_key: String, path: Array[Vector2i]) -> void:
	_path_cache[cache_key] = path.duplicate()
	_path_cache_order.append(cache_key)
	if max_cached_paths <= 0:
		_clear_path_cache()
		return
	while _path_cache_order.size() > max_cached_paths:
		var oldest_key: String = _path_cache_order.pop_front()
		_path_cache.erase(oldest_key)

func _clear_path_cache() -> void:
	_path_cache.clear()
	_path_cache_order.clear()

func _heap_push(cells: Array[Vector2i], priorities: Array[float], cell: Vector2i, priority: float) -> void:
	cells.append(cell)
	priorities.append(priority)
	var index: int = cells.size() - 1
	while index > 0:
		var parent_index: int = (index - 1) / 2
		if priorities[parent_index] <= priorities[index]:
			break
		_heap_swap(cells, priorities, index, parent_index)
		index = parent_index

func _heap_remove_root(cells: Array[Vector2i], priorities: Array[float]) -> void:
	var last_index: int = cells.size() - 1
	cells[0] = cells[last_index]
	priorities[0] = priorities[last_index]
	cells.remove_at(last_index)
	priorities.remove_at(last_index)
	if cells.is_empty():
		return

	var index: int = 0
	while true:
		var left_index: int = index * 2 + 1
		if left_index >= cells.size():
			return
		var right_index: int = left_index + 1
		var smallest_index: int = left_index
		if right_index < cells.size() and priorities[right_index] < priorities[left_index]:
			smallest_index = right_index
		if priorities[index] <= priorities[smallest_index]:
			return
		_heap_swap(cells, priorities, index, smallest_index)
		index = smallest_index

func _heap_swap(cells: Array[Vector2i], priorities: Array[float], index_a: int, index_b: int) -> void:
	var cell: Vector2i = cells[index_a]
	cells[index_a] = cells[index_b]
	cells[index_b] = cell
	var priority: float = priorities[index_a]
	priorities[index_a] = priorities[index_b]
	priorities[index_b] = priority
