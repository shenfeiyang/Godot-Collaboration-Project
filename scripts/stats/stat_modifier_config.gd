extends Resource
class_name StatModifierConfig

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")

# 要修正的属性标识。
@export var stat_id: StringName = &""
# 修正操作类型。
@export_enum("固定加值", "百分比加成", "独立乘区") var operation: int = SHARED_ENUMS.ModifierOperation.FLAT_ADD
# 修正值；百分比按 0.1 = 10% 录入。
@export var value: float = 0.0
