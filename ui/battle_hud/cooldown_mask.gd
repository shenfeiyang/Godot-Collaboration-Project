extends Control
class_name CooldownMask

@export_range(0.0, 1.0, 0.01) var radius_scale: float = 0.5
@export var mask_color: Color = Color(0.0, 0.0, 0.0, 0.5)

var _progress: float = 1.0

func set_progress(value: float) -> void:
	_progress = clamp(value, 0.0, 1.0)
	queue_redraw()

func set_mask_color(value: Color) -> void:
	mask_color = value
	queue_redraw()

func _draw() -> void:
	if _progress >= 1.0:
		return

	var center: Vector2 = size * 0.5
	var radius: float = min(size.x, size.y) * radius_scale
	if radius <= 0.0:
		return

	if _progress <= 0.0:
		draw_circle(center, radius, mask_color)
		return

	var cleared_sweep: float = TAU * _progress
	var remaining_sweep: float = TAU - cleared_sweep
	if remaining_sweep <= 0.0:
		return

	var start_angle: float = -PI * 0.5 + cleared_sweep
	var segment_count: int = max(3, int(ceil(remaining_sweep / TAU * 96.0)))
	var points: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()

	points.append(center)
	colors.append(mask_color)

	for index in range(segment_count + 1):
		var t: float = float(index) / float(segment_count)
		var angle: float = start_angle + remaining_sweep * t
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		colors.append(mask_color)

	draw_polygon(points, colors)
