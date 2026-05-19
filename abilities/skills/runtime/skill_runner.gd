extends RefCounted
class_name SkillRunner

const FIRE_PROJECTILE_EFFECT_CONFIG = preload("res://abilities/skills/definitions/fire_projectile_effect_config.gd")
const COMBAT_MANAGER = preload("res://scenes/combat_manager.gd")

var definition: SkillDefinition = null
var runtime_state: Dictionary = {}

func setup(skill_definition: SkillDefinition) -> void:
	definition = skill_definition
	runtime_state = {}

func can_cast() -> bool:
	return definition != null

func cast(context: SkillExecutionContext) -> void:
	if definition == null:
		return
	for effect_resource in definition.effects:
		if effect_resource == null or not effect_resource.enabled:
			continue
		if effect_resource is FIRE_PROJECTILE_EFFECT_CONFIG:
			_fire_projectile_effect(effect_resource as FireProjectileEffectConfig, context)

func tick(_delta: float, _context: SkillExecutionContext) -> void:
	pass

func is_active() -> bool:
	return false

func should_consume_cooldown_on_cast() -> bool:
	return true

func get_runtime_state() -> Dictionary:
	return runtime_state

func _fire_projectile_effect(effect: FireProjectileEffectConfig, context: SkillExecutionContext) -> void:
	if context.combat_manager == null:
		return
	var pattern_config: FirePatternConfig = effect.pattern_config
	var request: Dictionary = {
		COMBAT_MANAGER.REQUEST_SOURCE: context.caster,
		COMBAT_MANAGER.REQUEST_SPAWN_POSITION: context.spawn_position,
		COMBAT_MANAGER.REQUEST_DIRECTION: context.facing_direction,
		COMBAT_MANAGER.REQUEST_FACTION: context.faction,
	}
	if effect.bullet_scene != null:
		request[COMBAT_MANAGER.REQUEST_BULLET_SCENE] = effect.bullet_scene
	if pattern_config != null:
		request[COMBAT_MANAGER.REQUEST_FIRE_MODE] = pattern_config.fire_mode
		request[COMBAT_MANAGER.REQUEST_PATTERN_CONFIG] = _build_pattern_override(pattern_config, context)
	if effect.speed_override > 0.0:
		request[COMBAT_MANAGER.REQUEST_SPEED_OVERRIDE] = effect.speed_override
	if not effect.use_default_damage:
		request[COMBAT_MANAGER.REQUEST_DAMAGE] = effect.damage_override
	if not effect.extra.is_empty():
		request[COMBAT_MANAGER.REQUEST_EXTRA] = effect.extra.duplicate(true)
	context.combat_manager.request_fire(request)

func _build_pattern_override(pattern_config: FirePatternConfig, context: SkillExecutionContext) -> Dictionary:
	return {
		COMBAT_MANAGER.REQUEST_PATTERN_FIRE_MODE: pattern_config.fire_mode,
		COMBAT_MANAGER.REQUEST_PATTERN_FAN_BULLET_COUNT: pattern_config.fan_bullet_count,
		COMBAT_MANAGER.REQUEST_PATTERN_FAN_TOTAL_ANGLE_DEG: pattern_config.fan_total_angle_deg,
		COMBAT_MANAGER.REQUEST_PATTERN_RING_BULLET_COUNT: pattern_config.ring_bullet_count,
		COMBAT_MANAGER.REQUEST_PATTERN_RING_ANGLE_OFFSET_DEG: pattern_config.ring_angle_offset_deg,
		COMBAT_MANAGER.REQUEST_PATTERN_RANDOM_BULLET_COUNT: pattern_config.random_bullet_count,
		COMBAT_MANAGER.REQUEST_PATTERN_RANDOM_HALF_ANGLE_DEG: pattern_config.random_half_angle_deg,
		COMBAT_MANAGER.REQUEST_PATTERN_WAVE_BULLET_COUNT: pattern_config.wave_bullet_count,
		COMBAT_MANAGER.REQUEST_PATTERN_WAVE_TOTAL_ANGLE_DEG: pattern_config.wave_total_angle_deg,
		COMBAT_MANAGER.REQUEST_PATTERN_WAVE_AMPLITUDE_DEG: pattern_config.wave_amplitude_deg,
		COMBAT_MANAGER.REQUEST_PATTERN_WAVE_FREQUENCY: pattern_config.wave_frequency,
		COMBAT_MANAGER.REQUEST_PATTERN_SPIRAL_BULLET_COUNT: pattern_config.spiral_bullet_count,
		COMBAT_MANAGER.REQUEST_PATTERN_SPIRAL_STEP_ANGLE_DEG: pattern_config.spiral_step_angle_deg,
		COMBAT_MANAGER.REQUEST_PATTERN_SPIRAL_ANGLE_OFFSET_DEG: pattern_config.spiral_angle_offset_deg,
		COMBAT_MANAGER.REQUEST_PATTERN_SPIRAL_STATE_ANGLE_DEG: context.runtime_state.get(COMBAT_MANAGER.REQUEST_PATTERN_SPIRAL_STATE_ANGLE_DEG, 0.0),
	}
