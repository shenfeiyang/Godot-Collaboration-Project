extends RefCounted
class_name SkillSlotRuntime

const SKILL_RUNNER_SCRIPT = preload("res://abilities/skills/runtime/skill_runner.gd")

var slot_index: int = -1
var definition: SkillDefinition = null
var cooldown_remaining: float = 0.0
var runner: SkillRunner = null

func setup(initial_slot_index: int, skill_definition: SkillDefinition) -> void:
	slot_index = initial_slot_index
	definition = skill_definition
	if definition == null:
		runner = null
		cooldown_remaining = 0.0
		return
	var runner_script: Script = definition.runner_script
	if runner_script != null:
		runner = runner_script.new() as SkillRunner
	else:
		runner = SKILL_RUNNER_SCRIPT.new()
	if runner != null:
		runner.setup(definition)
	cooldown_remaining = 0.0

func tick(delta: float, context: SkillExecutionContext) -> void:
	cooldown_remaining = max(cooldown_remaining - delta, 0.0)
	if runner != null:
		context.slot_index = slot_index
		context.skill_definition = definition
		context.runtime_state = runner.get_runtime_state()
		runner.tick(delta, context)

func can_cast() -> bool:
	return definition != null and runner != null and cooldown_remaining <= 0.0 and runner.can_cast()

func try_cast(context: SkillExecutionContext) -> bool:
	if not can_cast():
		return false
	context.slot_index = slot_index
	context.skill_definition = definition
	context.runtime_state = runner.get_runtime_state()
	runner.cast(context)
	if runner.should_consume_cooldown_on_cast():
		cooldown_remaining = _get_cooldown_duration(context)
	return true

func get_cooldown_data() -> Dictionary:
	if definition == null:
		return {"remaining": 0.0, "duration": 0.0}
	return {
		"remaining": cooldown_remaining,
		"duration": _get_base_cooldown_duration(),
	}

func is_active() -> bool:
	return runner != null and runner.is_active()

func get_runtime_state() -> Dictionary:
	if runner == null:
		return {}
	return runner.get_runtime_state()

func _get_cooldown_duration(context: SkillExecutionContext) -> float:
	if definition == null:
		return 0.0
	if definition.use_attack_speed_scaling and context.caster != null and context.caster.has_method("get_attack_cooldown_interval"):
		return context.caster.get_attack_cooldown_interval()
	# 优先使用 SkillParamPack 的 cd_ms（毫秒转秒）
	var pack_cd: float = _get_param_pack_cd_sec()
	if pack_cd > 0.0:
		return pack_cd
	return _get_base_cooldown_duration()

func _get_base_cooldown_duration() -> float:
	return definition.cooldown if definition != null else 0.0

func _get_param_pack_cd_sec() -> float:
	if definition == null or definition.param_pack == null:
		return 0.0
	return float(definition.param_pack.cd_ms) / 1000.0
