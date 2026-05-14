extends CharacterBody2D
class_name Enemy

# 当前敌人所属阵营，供子弹过滤友军与自身时读取。
@export_enum("玩家", "怪物", "中立") var faction: int = 1
