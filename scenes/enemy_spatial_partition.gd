extends Node
class_name EnemySpatialPartition

# 空间划分网格边长；仅用于 separation 的近邻粗筛。
@export_range(4.0, 128.0, 1.0) var cell_size: float = 16.0

var _cells: Dictionary = {}
var _enemy_cells: Dictionary = {}

func register_enemy(enemy: Enemy) -> void:
	if enemy == null:
		return

	update_enemy_position(enemy, enemy.global_position)

func unregister_enemy(enemy: Enemy) -> void:
	if enemy == null:
		return
	if not _enemy_cells.has(enemy):
		return

	var cell: Vector2i = _enemy_cells[enemy]
	_remove_enemy_from_cell(enemy, cell)
	_enemy_cells.erase(enemy)

func update_enemy_position(enemy: Enemy, world_position: Vector2) -> void:
	if enemy == null:
		return

	var next_cell := _world_to_cell(world_position)
	if _enemy_cells.has(enemy):
		var current_cell: Vector2i = _enemy_cells[enemy]
		if current_cell == next_cell:
			return
		_remove_enemy_from_cell(enemy, current_cell)

	_enemy_cells[enemy] = next_cell
	var enemies_in_cell: Array = _cells.get(next_cell, [])
	enemies_in_cell.append(enemy)
	_cells[next_cell] = enemies_in_cell

func query_neighbors(world_position: Vector2, radius: float, exclude: Enemy = null) -> Array[Enemy]:
	var neighbors: Array[Enemy] = []
	if radius <= 0.0:
		return neighbors

	var effective_cell_size: float = max(cell_size, 0.001)
	var center_cell := _world_to_cell(world_position)
	var search_range: int = int(ceil(radius / effective_cell_size))
	for y in range(center_cell.y - search_range, center_cell.y + search_range + 1):
		for x in range(center_cell.x - search_range, center_cell.x + search_range + 1):
			var cell := Vector2i(x, y)
			var enemies_in_cell: Array = _cells.get(cell, [])
			for enemy in enemies_in_cell:
				if enemy == exclude:
					continue
				if not is_instance_valid(enemy):
					continue
				neighbors.append(enemy)

	return neighbors

func _remove_enemy_from_cell(enemy: Enemy, cell: Vector2i) -> void:
	if not _cells.has(cell):
		return

	var enemies_in_cell: Array = _cells[cell]
	var enemy_index := enemies_in_cell.find(enemy)
	if enemy_index != -1:
		enemies_in_cell.remove_at(enemy_index)
	if enemies_in_cell.is_empty():
		_cells.erase(cell)
	else:
		_cells[cell] = enemies_in_cell

func _world_to_cell(world_position: Vector2) -> Vector2i:
	var effective_cell_size: float = max(cell_size, 0.001)
	return Vector2i(
		int(floor(world_position.x / effective_cell_size)),
		int(floor(world_position.y / effective_cell_size))
	)
