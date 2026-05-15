extends RefCounted
class_name PhysicsLayers

# 统一定义项目内 2D 物理层编号、bit 值与常用遮罩，避免散落魔法数字。

# 世界地形、墙体和静态边界。
const WORLD_LAYER_NUMBER := 1
const WORLD_LAYER_BIT := 1 << (WORLD_LAYER_NUMBER - 1)
# 玩家本体，用于角色自身移动与受击判定。
const PLAYER_BODY_LAYER_NUMBER := 2
const PLAYER_BODY_LAYER_BIT := 1 << (PLAYER_BODY_LAYER_NUMBER - 1)
# 怪物本体，用于敌人移动与受击判定。
const ENEMY_BODY_LAYER_NUMBER := 3
const ENEMY_BODY_LAYER_BIT := 1 << (ENEMY_BODY_LAYER_NUMBER - 1)
# 玩家子弹，预留给后续更精细的子弹层过滤。
const PLAYER_BULLET_LAYER_NUMBER := 4
const PLAYER_BULLET_LAYER_BIT := 1 << (PLAYER_BULLET_LAYER_NUMBER - 1)
# 敌人子弹，预留给后续更精细的子弹层过滤。
const ENEMY_BULLET_LAYER_NUMBER := 5
const ENEMY_BULLET_LAYER_BIT := 1 << (ENEMY_BULLET_LAYER_NUMBER - 1)
# 拾取物与可交互对象。
const PICKUP_LAYER_NUMBER := 6
const PICKUP_LAYER_BIT := 1 << (PICKUP_LAYER_NUMBER - 1)
# 感知触发区、警戒圈、吸附范围等非阻挡检测区。
const SENSOR_LAYER_NUMBER := 7
const SENSOR_LAYER_BIT := 1 << (SENSOR_LAYER_NUMBER - 1)
# 陷阱、中立伤害区、环境危险物。
const HAZARD_LAYER_NUMBER := 8
const HAZARD_LAYER_BIT := 1 << (HAZARD_LAYER_NUMBER - 1)

# 玩家与怪物本体默认只和世界阻挡发生硬碰撞。
const PLAYER_BODY_MASK := WORLD_LAYER_BIT
const ENEMY_BODY_MASK := WORLD_LAYER_BIT
# 拾取物与触发区暂时只作为预留层，不参与硬碰撞阻挡。
const PICKUP_MASK := 0
const SENSOR_MASK := 0
const HAZARD_MASK := 0

static func get_bullet_layer_bit(faction: int) -> int:
	if faction == SharedEnums.Faction.PLAYER:
		return PLAYER_BULLET_LAYER_BIT
	if faction == SharedEnums.Faction.ENEMY:
		return ENEMY_BULLET_LAYER_BIT

	return 0

static func get_bullet_hit_mask(faction: int) -> int:
	if faction == SharedEnums.Faction.PLAYER:
		return WORLD_LAYER_BIT | ENEMY_BODY_LAYER_BIT | HAZARD_LAYER_BIT
	if faction == SharedEnums.Faction.ENEMY:
		return WORLD_LAYER_BIT | PLAYER_BODY_LAYER_BIT | HAZARD_LAYER_BIT

	return WORLD_LAYER_BIT | PLAYER_BODY_LAYER_BIT | ENEMY_BODY_LAYER_BIT | HAZARD_LAYER_BIT
