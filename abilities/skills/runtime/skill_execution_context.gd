extends RefCounted
class_name SkillExecutionContext

var caster: Node = null
var combat_manager: Node = null
var spawn_position: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.RIGHT
var faction: int = 0
var slot_index: int = -1
var runtime_state: Dictionary = {}
var skill_definition: SkillDefinition = null

func duplicate_shallow() -> SkillExecutionContext:
	var copy := SkillExecutionContext.new()
	copy.caster = caster
	copy.combat_manager = combat_manager
	copy.spawn_position = spawn_position
	copy.facing_direction = facing_direction
	copy.faction = faction
	copy.slot_index = slot_index
	copy.runtime_state = runtime_state
	copy.skill_definition = skill_definition
	return copy
