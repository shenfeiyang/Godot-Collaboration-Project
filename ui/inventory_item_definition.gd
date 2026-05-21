extends Resource
class_name InventoryItemDefinition

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")

# 物品唯一标识，供背包槽位和后续存档引用。
@export var item_id: StringName = &""
# Inspector 中显示用名称。
@export var display_name: String = ""
# 物品图标；未配置时界面回退到纯色占位块。
@export var icon: Texture2D
# 物品分类，供界面显示标签与后续筛选使用。
@export_enum("消耗品", "装备", "材料", "任务") var category: int = SHARED_ENUMS.ItemCategory.CONSUMABLE
# 物品子分类，供右侧筛选列表使用。
@export_enum("全部", "武器", "头部", "胸甲", "手部", "腿部", "脚部", "戒指", "项链", "饰物", "食物", "药水", "矿石", "草药", "骨材", "宝石", "其他") var subcategory: int = SHARED_ENUMS.ItemSubcategory.ALL
# 品质等级，供界面显示颜色与文本。
@export_enum("白:1", "绿:2", "蓝:3", "紫:4", "橙:5", "红:6", "金:7") var rarity: int = SHARED_ENUMS.ItemRarity.WHITE
# 物品说明。
@export_multiline var description: String = ""
# 堆叠上限；1 表示不可堆叠。
@export_range(1, 999, 1) var max_stack: int = 1
# 装备槽位；非装备物品保持 NONE。
@export_enum("无", "武器", "头部", "胸甲", "手部", "腿部", "脚部", "戒指", "项链", "饰物") var equip_slot: int = SHARED_ENUMS.EquipSlot.NONE
# 物品可提供的属性修正，供详情面板展示。
@export var stat_modifiers: Array[StatModifierConfig] = []
