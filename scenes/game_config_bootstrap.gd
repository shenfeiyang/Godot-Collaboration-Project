extends Node

const DEFAULT_PLAYER_SKILLS: Array[SkillDefinition] = [
	preload("res://abilities/skills/data/basic_attack_skill.tres"),
	preload("res://abilities/skills/data/skill1_definition.tres"),
	preload("res://abilities/skills/data/skill2_definition.tres"),
	preload("res://abilities/skills/data/skill3_definition.tres"),
	preload("res://abilities/skills/data/skill4_definition.tres"),
]
const STAT_MODIFIER_CONFIG_SCRIPT = preload("res://scripts/stats/stat_modifier_config.gd")

@export var game_run_config: GameRunConfig
@export var player_path: NodePath = NodePath("../Entities/Player")
@export var enemy_spawner_path: NodePath = NodePath("../EnemySpawner")

func _enter_tree() -> void:
	if game_run_config == null:
		push_warning("GameConfigBootstrap missing game_run_config")
		return
	var player: Player = get_node_or_null(player_path) as Player
	if player == null:
		push_warning("GameConfigBootstrap missing player reference")
	else:
		_apply_player_config(player)
	var enemy_spawner: Node = get_node_or_null(enemy_spawner_path)
	if enemy_spawner == null:
		push_warning("GameConfigBootstrap missing enemy spawner reference")
	elif enemy_spawner.has_method("apply_stage_spawn_config"):
		enemy_spawner.apply_stage_spawn_config(game_run_config.stage_spawn_config)
	else:
		push_warning("GameConfigBootstrap target spawner missing apply_stage_spawn_config")

func _apply_player_config(player: Player) -> void:
	var stats_component: StatsComponent = player.get_node_or_null("StatsComponent") as StatsComponent
	if stats_component != null:
		if game_run_config.player_base_stats != null:
			stats_component.base_stats_config = game_run_config.player_base_stats
		stats_component.set_external_modifiers(_build_equipment_modifiers())
	var resolved_skills: Array[SkillDefinition] = _build_player_skills()
	if not resolved_skills.is_empty():
		player.apply_configured_skill_definitions(resolved_skills)

func _build_equipment_modifiers() -> Array[StatModifierConfig]:
	var modifiers: Array[StatModifierConfig] = []
	for equipment in game_run_config.equipped_items:
		if equipment == null:
			continue
		for modifier in equipment.stat_modifiers:
			if modifier == null:
				continue
			var copied_modifier: StatModifierConfig = STAT_MODIFIER_CONFIG_SCRIPT.new()
			copied_modifier.stat_id = modifier.stat_id
			copied_modifier.operation = modifier.operation
			copied_modifier.value = modifier.value
			modifiers.append(copied_modifier)
	return modifiers

func _build_player_skills() -> Array[SkillDefinition]:
	var resolved_skills: Array[SkillDefinition] = []
	for definition in DEFAULT_PLAYER_SKILLS:
		resolved_skills.append(definition)
	var skill_slot_index: int = 1
	for equipment in game_run_config.equipped_items:
		if equipment == null:
			continue
		for skill_definition in equipment.granted_skills:
			if skill_definition == null:
				push_warning("EquipmentDefinition contains null skill reference")
				continue
			if skill_slot_index >= resolved_skills.size():
				break
			resolved_skills[skill_slot_index] = skill_definition
			skill_slot_index += 1
		if skill_slot_index >= resolved_skills.size():
			break
	return resolved_skills
