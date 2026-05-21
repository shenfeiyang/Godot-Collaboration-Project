extends RefCounted
class_name SharedEnums

# 统一定义项目内可切换的发射模式编号，供角色、战斗管理器和弹幕解析器共用。
enum FireMode {
	SINGLE = 0,
	FAN = 1,
	RING = 2,
	RANDOM_SCATTER = 3,
	WAVE = 4,
	SPIRAL = 5,
}

# 统一定义项目内的阵营编号，供角色、子弹和命中判定共用。
enum Faction {
	PLAYER = 0,
	ENEMY = 1,
	NEUTRAL = 2,
}

# 统一定义属性修正操作类型。
enum ModifierOperation {
	FLAT_ADD = 0,
	PERCENT_ADD = 1,
	PERCENT_MUL = 2,
}

# 统一定义 buff 再次应用时的叠层策略。
enum BuffStackingRule {
	REFRESH_DURATION = 0,
	ADD_STACK = 1,
	INDEPENDENT_INSTANCE = 2,
}

# 统一定义物品分类，供背包界面展示和后续筛选使用。
enum ItemCategory {
	CONSUMABLE = 0,
	EQUIPMENT = 1,
	MATERIAL = 2,
	QUEST = 3,
}

# 统一定义物品右侧筛选子分类。
enum ItemSubcategory {
	ALL = 0,
	WEAPON = 1,
	HEAD = 2,
	CHEST = 3,
	HANDS = 4,
	LEGS = 5,
	FEET = 6,
	RING = 7,
	NECK = 8,
	ARTIFACT = 9,
	FOOD = 10,
	POTION = 11,
	ORE = 12,
	HERB = 13,
	BONE = 14,
	GEM = 15,
	OTHER = 16,
}

# 统一定义物品品质，供背包界面显示颜色和标签。
enum ItemRarity {
	WHITE = 1,
	GREEN = 2,
	BLUE = 3,
	PURPLE = 4,
	ORANGE = 5,
	RED = 6,
	GOLD = 7,
}

# 统一定义装备槽位，供装备区和物品配置共用。
enum EquipSlot {
	NONE = 0,
	WEAPON = 1,
	HEAD = 2,
	CHEST = 3,
	HANDS = 4,
	LEGS = 5,
	FEET = 6,
	RING = 7,
	NECK = 8,
	ARTIFACT = 9,
	ACCESSORY = ARTIFACT,
}
