extends Node
class_name RuntimePerformanceMonitor

# 需要读取的流场管理器路径。
@export_group("节点引用")
@export var flow_field_manager_path: NodePath
@export var enemy_container_path: NodePath

# 控制性能日志输出频率。
@export_group("监控配置")
@export var monitor_enabled: bool = true
@export_range(0.2, 5.0, 0.1) var report_interval: float = 1.0

var _flow_field_manager: FlowFieldManager = null
var _enemy_container: Node = null
var _report_timer: float = 0.0

func _ready() -> void:
	_flow_field_manager = get_node_or_null(flow_field_manager_path) as FlowFieldManager
	_enemy_container = get_node_or_null(enemy_container_path)

func _process(delta: float) -> void:
	if not monitor_enabled:
		return

	_report_timer += delta
	if _report_timer < report_interval:
		return

	_report_timer = 0.0
	_report_performance_snapshot()

func _report_performance_snapshot() -> void:
	var flow_stats := FlowFieldManager.get_debug_rebuild_stats()
	var enemy_stats := Enemy.get_debug_physics_stats()
	var flow_last_ms := float(flow_stats.get("last_usec", 0)) / 1000.0
	var flow_avg_ms := float(flow_stats.get("average_usec", 0.0)) / 1000.0
	var enemy_last_ms := float(enemy_stats.get("last_usec", 0)) / 1000.0
	var enemy_avg_ms := float(enemy_stats.get("average_usec", 0.0)) / 1000.0
	var enemy_count := _enemy_container.get_child_count() if _enemy_container != null else 0
	var flow_last_frames := int(flow_stats.get("last_frames", 0))
	var flow_avg_frames := float(flow_stats.get("average_frames", 0.0))
	var rebuild_in_progress := _flow_field_manager.is_rebuild_in_progress() if _flow_field_manager != null else false
	print(
		"[Perf] enemies=", enemy_count,
		" flow_last_ms=", snapped(flow_last_ms, 0.01),
		" flow_avg_ms=", snapped(flow_avg_ms, 0.01),
		" flow_last_frames=", flow_last_frames,
		" flow_avg_frames=", snapped(flow_avg_frames, 0.01),
		" flow_building=", rebuild_in_progress,
		" flow_count=", int(flow_stats.get("count", 0)),
		" enemy_last_ms=", snapped(enemy_last_ms, 0.01),
		" enemy_avg_ms=", snapped(enemy_avg_ms, 0.01),
		" enemy_samples=", int(enemy_stats.get("count", 0))
	)
