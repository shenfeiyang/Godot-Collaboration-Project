extends Node2D
class_name FlowFieldDebugVisualizer

# 需要读取的流场管理器路径。
@export_group("节点引用")
@export var flow_field_manager_path: NodePath

# 总开关；关闭后不绘制任何调试内容。
@export_group("显示开关")
@export var debug_enabled: bool = true
@export var show_walkable_cells: bool = true
@export var show_target_cell: bool = true
@export var show_flow_arrows: bool = true

# walkable 区域底色。
@export_group("显示样式")
@export var walkable_fill_color: Color = Color(0.15, 0.75, 0.35, 0.16)
# 目标格高亮颜色。
@export var target_cell_color: Color = Color(1.0, 0.75, 0.2, 0.45)
# 流向箭头颜色。
@export var flow_arrow_color: Color = Color(0.35, 0.8, 1.0, 0.95)
# 箭头相对 tile 的长度比例。
@export_range(0.1, 0.6, 0.01) var arrow_length_scale: float = 0.36
# 箭头头部长度比例。
@export_range(0.05, 0.4, 0.01) var arrow_head_scale: float = 0.18
# 线宽。
@export_range(1.0, 4.0, 0.5) var line_width: float = 1.5

var _flow_field_manager: FlowFieldManager = null

func _ready() -> void:
	_flow_field_manager = get_node_or_null(flow_field_manager_path) as FlowFieldManager
	if _flow_field_manager != null and not _flow_field_manager.flow_field_rebuilt.is_connected(_on_flow_field_rebuilt):
		_flow_field_manager.flow_field_rebuilt.connect(_on_flow_field_rebuilt)
	queue_redraw()

func _draw() -> void:
	if not debug_enabled:
		return
	if _flow_field_manager == null:
		return

	var tile_map := _flow_field_manager.get_debug_tile_map()
	if tile_map == null or tile_map.tile_set == null:
		return

	var tile_size := Vector2(tile_map.tile_set.tile_size)
	if tile_size.x <= 0.0 or tile_size.y <= 0.0:
		return

	if show_walkable_cells:
		_draw_walkable_cells(tile_map, tile_size)
	if show_target_cell:
		_draw_target_cell(tile_map, tile_size)
	if show_flow_arrows:
		_draw_flow_arrows(tile_size)

func _draw_walkable_cells(tile_map: TileMapLayer, tile_size: Vector2) -> void:
	var walkable_cells := _flow_field_manager.get_debug_walkable_cells()
	for cell in walkable_cells.keys():
		if not walkable_cells[cell]:
			continue
		var center: Vector2 = to_local(_flow_field_manager._cell_to_world(cell))
		var rect := Rect2(center - tile_size * 0.5, tile_size)
		draw_rect(rect, walkable_fill_color, true)

func _draw_target_cell(tile_map: TileMapLayer, tile_size: Vector2) -> void:
	var target_cell := _flow_field_manager.get_debug_target_cell()
	var center := to_local(_flow_field_manager._cell_to_world(target_cell))
	var rect := Rect2(center - tile_size * 0.5, tile_size)
	draw_rect(rect, target_cell_color, false, line_width * 1.5)

func _draw_flow_arrows(tile_size: Vector2) -> void:
	var flow_field := _flow_field_manager.get_debug_flow_field()
	var arrow_length: float = min(tile_size.x, tile_size.y) * arrow_length_scale
	var head_length: float = min(tile_size.x, tile_size.y) * arrow_head_scale
	for cell in flow_field.keys():
		var direction: Vector2 = flow_field[cell]
		if direction == Vector2.ZERO:
			continue

		var start: Vector2 = to_local(_flow_field_manager._cell_to_world(cell))
		var end: Vector2 = start + direction.normalized() * arrow_length
		draw_line(start, end, flow_arrow_color, line_width)

		var back_direction: Vector2 = -direction.normalized()
		var head_left: Vector2 = end + back_direction.rotated(0.45) * head_length
		var head_right: Vector2 = end + back_direction.rotated(-0.45) * head_length
		draw_line(end, head_left, flow_arrow_color, line_width)
		draw_line(end, head_right, flow_arrow_color, line_width)

func _on_flow_field_rebuilt() -> void:
	queue_redraw()
