extends RefCounted
class_name BuffRuntime

var config: BuffConfig = null
var source: Node = null
var remaining_duration: float = 0.0
var stacks: int = 1

func _init(initial_config: BuffConfig = null, initial_source: Node = null) -> void:
	config = initial_config
	source = initial_source
	remaining_duration = config.duration if config != null else 0.0

func tick(delta: float) -> bool:
	if config == null:
		return true
	if config.duration <= 0.0:
		return false
	remaining_duration = max(remaining_duration - delta, 0.0)
	return remaining_duration <= 0.0

func refresh_duration() -> void:
	if config == null:
		return
	remaining_duration = config.duration

func add_stack() -> void:
	if config == null:
		return
	stacks = min(stacks + 1, config.max_stacks)

func get_modifiers() -> Array[StatModifierConfig]:
	if config == null:
		return []
	return config.modifiers
