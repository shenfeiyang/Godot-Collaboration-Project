extends Resource
class_name SkillDefinition

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")

# 技能顶层定义，作为 Inspector 编辑与表格导入的统一模型。
@export var skill_id: StringName = &""
@export var display_name: String = ""

# ── skill.xlsx / skill sheet 扩展字段 ──

## 技能层级：MainSk（主技能）/ SubSk（子技能）
@export var tier: String = "MainSk"
## 释放单位：Player / Monster / Summon
@export var caster: String = "Player"
## 技能主标签，如 Projectile / Throw / Laser / Chain / Area / Melee
@export var main_tag: String = ""
## 技能子标签，如 Proj_Lin / Proj_Trk / Laser_Inst / Chain_Dur
@export var sub_tag: String = ""
## 伤害标签：Phys / Ele
@export var dmg_tag: String = "Phys"

## 技能美术表现包 ID，引用 SkillArtConfig
@export var art_pack_id: StringName = &""
## 技能基础参数包 ID，引用 SkillParamPack
@export var param_pack_id: StringName = &""
## 技能基础参数包（直接引用），运行时优先读这个
@export var param_pack: SkillParamPack
## 技能触发包 ID，引用 TriggerConfig
@export var trigger_pack_id: StringName = &""
## 技能 Buff 包 ID，引用 BuffConfig
@export var buff_pack_id: StringName = &""

# ── 原有字段 ──

@export var icon: Texture2D
@export_range(0.0, 30.0, 0.01) var cooldown: float = 0.0
@export_enum("朝向", "自身") var targeting_mode: int = 0
@export var is_basic_attack: bool = false
@export var use_attack_speed_scaling: bool = false
@export var runner_script: Script
@export var effects: Array[SkillEffectConfig] = []
@export var tags: Array[StringName] = []
@export var editor_metadata: Dictionary = {}
