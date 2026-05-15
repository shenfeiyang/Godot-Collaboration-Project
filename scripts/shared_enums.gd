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
