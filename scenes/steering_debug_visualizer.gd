extends Node2D
class_name SteeringDebugVisualizer

# 需要读取的敌人容器路径。
@export_group("节点引用")
@export var enemy_container_path: NodePath

# 总开关；关闭后不绘制任何调试内容。
@export_group("显示开关")
@export var debug_enabled: bool = true
@export var show_desired_velocity: bool = true
@export var show_avoidance_velocity: bool = true
@export var show_recovery_velocity: bool = true
@export var show_separation_velocity: bool = true
@export var show_final_velocity: bool = true

# 不同 steering 向量的显示样式。
@export_group("显示样式")
@export var desired_velocity_color: Color = Color(0.35, 0.8, 1.0, 0.95)
@export var avoidance_velocity_color: Color = Color(1.0, 0.8, 0.2, 0.95)
@export var recovery_velocity_color: Color = Color(1.0, 0.45, 0.35, 0.95)
@export var separation_velocity_color: Color = Color(1.0, 0.45, 0.7, 0.95)
@export var final_velocity_color: Color = Color(0.45, 1.0, 0.45, 0.95)
@export var recovering_final_velocity_color: Color = Color(1.0, 0.35, 0.35, 1.0)
@export_range(0.1, 2.0, 0.05) var vector_scale: float = 0.45
@export_range(0.0, 16.0, 0.5) var anchor_offset_y: float = 10.0
@export_range(0.05, 0.5, 0.01) var arrow_head_scale: float = 0.24
@export_range(1.0, 4.0, 0.5) var line_width: float = 1.5

var _enemy_container: Node2D = null

func _ready() -> void:
	_enemy_container = get_node_or_null(enemy_container_path) as Node2D
	queue_redraw()

func _process(_delta: float) -> void:
	if not debug_enabled:
		return
	queue_redraw()

func _draw() -> void:
	if not debug_enabled:
		return
	if _enemy_container == null:
		_enemy_container = get_node_or_null(enemy_container_path) as Node2D
		if _enemy_container == null:
			return

	for child in _enemy_container.get_children():
		var enemy := child as Enemy
		if enemy == null:
			continue
		_draw_enemy_vectors(enemy)

func _draw_enemy_vectors(enemy: Enemy) -> void:
	var anchor := to_local(enemy.global_position + Vector2(0.0, -anchor_offset_y))
	var desired_velocity := enemy.get_debug_desired_velocity()
	var avoidance_velocity := enemy.get_debug_avoidance_velocity()
	var recovery_velocity := enemy.get_debug_recovery_velocity()
	var separation_velocity := enemy.get_debug_separation_velocity()
	var final_velocity := enemy.get_debug_final_velocity()
	var current_final_color := recovering_final_velocity_color if enemy.get_debug_is_recovering() else final_velocity_color

	if show_desired_velocity:
		_draw_velocity_arrow(anchor, desired_velocity, desired_velocity_color)
	if show_avoidance_velocity:
		_draw_velocity_arrow(anchor, avoidance_velocity, avoidance_velocity_color)
	if show_recovery_velocity:
		_draw_velocity_arrow(anchor, recovery_velocity, recovery_velocity_color)
	if show_separation_velocity:
		_draw_velocity_arrow(anchor, separation_velocity, separation_velocity_color)
	if show_final_velocity:
		_draw_velocity_arrow(anchor, final_velocity, current_final_color)

func _draw_velocity_arrow(origin: Vector2, velocity_vector: Vector2, color: Color) -> void:
	if velocity_vector == Vector2.ZERO:
		return

	var scaled_vector := velocity_vector * vector_scale
	var end := origin + scaled_vector
	draw_line(origin, end, color, line_width)

	var head_length: float = max(scaled_vector.length() * arrow_head_scale, 4.0)
	var back_direction := -scaled_vector.normalized()
	var head_left := end + back_direction.rotated(0.45) * head_length
	var head_right := end + back_direction.rotated(-0.45) * head_length
	draw_line(end, head_left, color, line_width)
	draw_line(end, head_right, color, line_width)
