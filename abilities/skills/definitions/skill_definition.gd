extends Resource
class_name SkillDefinition

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")

# 技能顶层定义，作为 Inspector 编辑与表格导入的统一模型。
@export var skill_id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D
@export_range(0.0, 30.0, 0.01) var cooldown: float = 0.0
@export_enum("朝向", "自身") var targeting_mode: int = 0
@export var is_basic_attack: bool = false
@export var use_attack_speed_scaling: bool = false
@export var runner_script: Script
@export var effects: Array[SkillEffectConfig] = []
@export var tags: Array[StringName] = []
@export var editor_metadata: Dictionary = {}
