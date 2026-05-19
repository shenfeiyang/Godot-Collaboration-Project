extends SkillRunner
class_name Skill1ClusterRunner

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")

func cast(context: SkillExecutionContext) -> void:
	if definition == null:
		return
	for effect_resource in definition.effects:
		if effect_resource == null or not effect_resource.enabled:
			continue
		if effect_resource is FireProjectileEffectConfig:
			_fire_cluster_projectile(effect_resource as FireProjectileEffectConfig, context)

func _fire_cluster_projectile(effect: FireProjectileEffectConfig, context: SkillExecutionContext) -> void:
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
		var extra_payload: Dictionary = effect.extra.duplicate(true)
		extra_payload["cluster_pattern_config"] = {
			COMBAT_MANAGER.REQUEST_PATTERN_FIRE_MODE: SHARED_ENUMS.FireMode.RING,
			COMBAT_MANAGER.REQUEST_PATTERN_RING_BULLET_COUNT: int(extra_payload.get("skill1_cluster_ring_bullet_count", 1)),
			COMBAT_MANAGER.REQUEST_PATTERN_RING_ANGLE_OFFSET_DEG: extra_payload.get("skill1_cluster_ring_angle_offset_deg", 0.0),
		}
		request[COMBAT_MANAGER.REQUEST_EXTRA] = extra_payload
	context.combat_manager.request_fire(request)
