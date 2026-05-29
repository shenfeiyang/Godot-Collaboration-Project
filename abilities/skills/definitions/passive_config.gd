extends Resource
class_name PassiveConfig

## 被动效果表 —— 对应 skill.xlsx / skillPas sheet
## 定义装备/天赋/肉鸽词条的被动效果。

@export var passive_id: StringName = &""

## 被动名称
@export var display_name: String = ""

## 被动描述
@export var description: String = ""

## 来源类型：装备 / 天赋 / 肉鸽
@export var source_type: String = ""

## 触发事件：常驻 / 命中时 / 击杀时 / 生命值低于 / 累计命中时
@export var trigger_event: String = ""

## 触发条件表达式，如 "HP<30%"、"命中次数>=10"、"目标拥有Buff=点燃"
@export var trigger_condition: String = ""

## 效果类型：属性加成 / 伤害增幅 / 状态附加 / 特殊机制
@export var effect_type: String = ""

## 目标规则：自身 / 当前目标 / 最近敌人
@export var target_rule: String = ""

## 效果主参数，如 "暴击率+1500"、"额外子弹=2"
@export var param1: String = ""

## 效果副参数，如触发概率等
@export var param2: String = ""

## 持续时间(毫秒)，0 = 永久/常驻
@export_range(0, 86400000) var duration_ms: int = 0

## 叠层上限，0 = 不可叠
@export_range(0, 999) var max_stack: int = 0

## 叠层规则：叠加 / 刷新 / 取最高
@export var stack_rule: String = ""

## 被动标签，服务 build/装备/祝福联动，多个用 | 分隔
@export var tags: String = ""

## 备注
@export var remark: String = ""
