extends Resource
class_name BuffConfig

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")

# buff 唯一标识，供刷新、去重和移除时使用。
@export var buff_id: StringName = &""
# Inspector 中显示用名称。
@export var display_name: String = ""
# buff 默认持续时间，单位为秒；0 表示瞬时或永久由外部控制。
@export_range(0.0, 3600.0, 0.01) var duration: float = 0.0
# 同类 buff 最多可叠加层数。
@export_range(1, 99, 1) var max_stacks: int = 1
# 同类 buff 再次添加时的叠层策略。
@export_enum("刷新持续时间", "叠层", "独立实例") var stacking_rule: int = SHARED_ENUMS.BuffStackingRule.REFRESH_DURATION
# buff 生效时附带的属性修正列表。
@export var modifiers: Array[StatModifierConfig] = []
