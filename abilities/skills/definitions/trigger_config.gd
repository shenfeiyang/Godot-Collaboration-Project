extends Resource
class_name TriggerConfig

## 技能触发包 —— 对应 skill.xlsx / skillTrig sheet
## 定义技能的额外派生触发规则。一个触发包可按 order 配置多条规则。

@export var trigger_pack_id: StringName = &""

## 执行顺序；同一触发包内按从小到大执行
@export_range(1, 100) var order: int = 1

## 触发事件：Trig_Hit / Trig_Crit / Trig_Kill
@export var trigger_event: String = "Trig_Hit"

## 触发参数，如累计命中次数达到此值才触发
@export var trig_param: int = 1

## 被触发的技能 ID（子技能或派生效果技能）
@export var trigger_skill_id: StringName = &""

## 触发延迟时间，单位毫秒；0 = 无延迟
@export_range(0, 30000) var trigger_delay_ms: int = 0

## 最大触发次数；0 = 不限次数
@export_range(0, 999) var max_trigger_count: int = 0
