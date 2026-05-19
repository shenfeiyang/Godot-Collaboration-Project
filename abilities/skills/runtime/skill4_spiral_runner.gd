extends SkillRunner
class_name Skill4SpiralRunner

var _active_remaining: float = 0.0
var _fire_cooldown_remaining: float = 0.0
var _effect: FireProjectileEffectConfig = null

func setup(skill_definition: SkillDefinition) -> void:
	super.setup(skill_definition)
	_effect = _find_primary_effect()
	runtime_state["spiral_state_angle_deg"] = 0.0
	runtime_state["active"] = false

func can_cast() -> bool:
	return definition != null and _effect != null and not is_active()

func cast(context: SkillExecutionContext) -> void:
	if _effect == null or is_active():
		return
	_active_remaining = definition.editor_metadata.get("active_duration", 0.0)
	_fire_cooldown_remaining = 0.0
	runtime_state["active"] = _active_remaining > 0.0
	_fire_once(context)

func tick(delta: float, context: SkillExecutionContext) -> void:
	if not is_active():
		return
	_active_remaining = max(_active_remaining - delta, 0.0)
	if _active_remaining <= 0.0:
		runtime_state["active"] = false
		return
	_fire_cooldown_remaining = max(_fire_cooldown_remaining - delta, 0.0)
	var interval: float = _get_interval()
	while is_active() and _fire_cooldown_remaining <= 0.0:
		_fire_once(context)
		_fire_cooldown_remaining += interval
		if _active_remaining <= 0.0:
			runtime_state["active"] = false

func is_active() -> bool:
	return bool(runtime_state.get("active", false))

func should_consume_cooldown_on_cast() -> bool:
	return true

func _fire_once(context: SkillExecutionContext) -> void:
	if context.combat_manager == null or _effect == null:
		return
	var pattern_config: FirePatternConfig = _effect.pattern_config
	var request: Dictionary = {
		COMBAT_MANAGER.REQUEST_SOURCE: context.caster,
		COMBAT_MANAGER.REQUEST_SPAWN_POSITION: context.spawn_position,
		COMBAT_MANAGER.REQUEST_DIRECTION: context.facing_direction,
		COMBAT_MANAGER.REQUEST_FACTION: context.faction,
	}
	if _effect.bullet_scene != null:
		request[COMBAT_MANAGER.REQUEST_BULLET_SCENE] = _effect.bullet_scene
	if pattern_config != null:
		request[COMBAT_MANAGER.REQUEST_FIRE_MODE] = pattern_config.fire_mode
		request[COMBAT_MANAGER.REQUEST_PATTERN_CONFIG] = _build_pattern_override(pattern_config, context)
	if _effect.speed_override > 0.0:
		request[COMBAT_MANAGER.REQUEST_SPEED_OVERRIDE] = _effect.speed_override
	if not _effect.use_default_damage:
		request[COMBAT_MANAGER.REQUEST_DAMAGE] = _effect.damage_override
	if not _effect.extra.is_empty():
		request[COMBAT_MANAGER.REQUEST_EXTRA] = _effect.extra.duplicate(true)
	context.combat_manager.request_fire(request)
	var step_angle: float = pattern_config.spiral_step_angle_deg if pattern_config != null else 0.0
	runtime_state["spiral_state_angle_deg"] = fposmod(runtime_state.get("spiral_state_angle_deg", 0.0) + step_angle, 360.0)

func _get_interval() -> float:
	return max(definition.editor_metadata.get("interval", 0.01), 0.01)

func _find_primary_effect() -> FireProjectileEffectConfig:
	for effect_resource in definition.effects:
		if effect_resource is FireProjectileEffectConfig:
			return effect_resource as FireProjectileEffectConfig
	return null
