extends SkillEffectConfig
class_name FireProjectileEffectConfig

@export var bullet_scene: PackedScene
@export var pattern_config: FirePatternConfig
@export_range(0.0, 5000.0, 1.0) var speed_override: float = 0.0
@export var use_default_damage: bool = true
@export_range(0.0, 5000.0, 1.0) var damage_override: float = 0.0
@export var extra: Dictionary = {}
