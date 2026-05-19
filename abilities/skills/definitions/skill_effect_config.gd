extends Resource
class_name SkillEffectConfig

# 技能效果基类，供后续扩展位移、增益、范围伤害等效果。
@export var enabled: bool = true
@export_range(0.0, 10.0, 0.01) var delay: float = 0.0
