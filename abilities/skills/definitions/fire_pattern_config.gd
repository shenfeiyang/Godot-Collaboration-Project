extends Resource
class_name FirePatternConfig

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")

# 弹幕模式配置资源，供技能定义复用并支持未来表格导入。
@export_enum("单发", "扇形", "环形", "随机散射", "波浪", "螺旋") var fire_mode: int = SHARED_ENUMS.FireMode.SINGLE
@export_range(1, 64, 1) var fan_bullet_count: int = 5
@export_range(0.0, 360.0, 1.0) var fan_total_angle_deg: float = 60.0
@export_range(1, 64, 1) var ring_bullet_count: int = 8
@export_range(0.0, 360.0, 1.0) var ring_angle_offset_deg: float = 0.0
@export_range(1, 64, 1) var random_bullet_count: int = 5
@export_range(0.0, 180.0, 1.0) var random_half_angle_deg: float = 20.0
@export_range(1, 64, 1) var wave_bullet_count: int = 7
@export_range(0.0, 360.0, 1.0) var wave_total_angle_deg: float = 60.0
@export_range(0.0, 180.0, 1.0) var wave_amplitude_deg: float = 10.0
@export_range(0.0, 8.0, 0.1) var wave_frequency: float = 1.0
@export_range(1, 16, 1) var spiral_bullet_count: int = 1
@export_range(0.0, 360.0, 1.0) var spiral_step_angle_deg: float = 18.0
@export_range(0.0, 360.0, 1.0) var spiral_angle_offset_deg: float = 0.0
