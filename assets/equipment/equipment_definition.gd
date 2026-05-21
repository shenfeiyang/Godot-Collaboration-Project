extends Resource
class_name EquipmentDefinition

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")

# 装备唯一标识，供外部配置和后续存档引用。
@export var equipment_id: StringName = &""
# 装备显示名称。
@export var display_name: String = ""
# 装备图标；未配置时可由界面回退到占位表现。
@export var icon: Texture2D
# 装备品质，供背包与装备槽显示外框颜色。
@export_enum("白:1", "绿:2", "蓝:3", "紫:4", "橙:5", "红:6", "金:7") var rarity: int = SHARED_ENUMS.ItemRarity.WHITE
# 装备部位文本，第一版仅做展示和表格映射占位。
@export var slot_type: StringName = &""
# 装备授予的技能列表，按顺序汇总到玩家技能槽。
@export var granted_skills: Array[SkillDefinition] = []
# 装备附带的属性词条；第一版先建模，后续再接入战斗结算。
@export var stat_modifiers: Array[StatModifierConfig] = []
