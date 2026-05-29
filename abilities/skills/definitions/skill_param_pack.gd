extends Resource
class_name SkillParamPack

## 技能基础参数包 —— 对应 skill.xlsx / skillParam sheet
## 定义技能的核心行为参数，一个参数包可被多个技能复用。

@export var param_pack_id: StringName = &""

## 伤害倍率，万分比（10000 = 100%）
@export_range(0, 100000) var dmg_rate: int = 10000

## 技能冷却/释放间隔，单位毫秒
@export_range(0, 300000) var cd_ms: int = 0

## 索敌/攻击范围
@export_range(0, 5000) var seek_range: int = 0

## 索敌目标类型：NearU / MaxHpU / Player
@export var target_search: String = "NearU"

## 缩放比例，万分比（10000 = 1倍）
@export_range(0, 100000) var scale: int = 10000

## 覆盖空间：0 = 全区域，1 = 仅对地
@export_range(0, 1) var space: int = 0

## 一次释放生成的子弹/技能数量
@export_range(1, 256) var bullet_num: int = 1

## 一轮攻击内的打击波次/连发次数
@export_range(1, 256) var atk_num: int = 1

## 子弹飞行速度；即时射线/链类填 0
@export_range(0, 10000) var bullet_speed: int = 0

## 穿透怪物数量/闪电链链接单位数
@export_range(0, 100) var pierc: int = 0

## 技能或子弹持续时间，单位毫秒
@export_range(0, 300000) var duration_ms: int = 0

## 冷却计时时机：0 = 持续时间结束前开始计时，1 = 结束后开始
@export_range(0, 1) var cd_open: int = 0

## 击退配置，格式 "重量阈值|击退距离"，如 "5|100"
@export var repel: String = ""

## 伤害次数上限，达到此值技能结束；0 = 不限
@export_range(0, 999) var impact_count: int = 0

## 对同一单位再次造成伤害的时间间隔，单位毫秒；0 = 仅造成1次伤害
@export_range(0, 30000) var impact_interval_ms: int = 0
