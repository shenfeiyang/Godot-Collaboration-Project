extends CharacterBody2D
class_name Player

const SHARED_ENUMS = preload("res://scripts/shared_enums.gd")
const PHYSICS_LAYERS = preload("res://scripts/physics_layers.gd")
const STAT_IDS = preload("res://scripts/stats/stat_ids.gd")
const SKILL_SLOT_RUNTIME_SCRIPT = preload("res://abilities/skills/runtime/skill_slot_runtime.gd")
const SKILL_EXECUTION_CONTEXT_SCRIPT = preload("res://abilities/skills/runtime/skill_execution_context.gd")
const DEFAULT_BASIC_ATTACK_SKILL = preload("res://abilities/skills/data/basic_attack_skill.tres")
const DEFAULT_SKILL_1 = preload("res://abilities/skills/data/skill1_definition.tres")
const DEFAULT_SKILL_2 = preload("res://abilities/skills/data/skill2_definition.tres")
const DEFAULT_SKILL_3 = preload("res://abilities/skills/data/skill3_definition.tres")
const DEFAULT_SKILL_4 = preload("res://abilities/skills/data/skill4_definition.tres")

# 默认动画前缀
const NORMAL_ANIMATION_PREFIX := &"normal"
const ARMED_ANIMATION_PREFIX := &"armed"
const SKILL_SLOT_BASIC_ATTACK: int = 0
const SKILL_SLOT_1: int = 1
const SKILL_SLOT_2: int = 2
const SKILL_SLOT_3: int = 3
const SKILL_SLOT_4: int = 4
const INVALID_SKILL_SLOT: int = -1
const ACTION_NORMAL_ATTACK := &"normal_attack"
const ACTION_SKILL_1 := &"skill1"
const ACTION_SKILL_2 := &"skill2"
const ACTION_SKILL_3 := &"skill3"
const ACTION_SKILL_4 := &"skill4"

# 角色动画节点，负责播放四方形移动画
@onready var body_sprite: AnimatedSprite2D = $BodySprite
@onready var armed_effect_sprite: AnimatedSprite2D = $ArmedEffectSprite
@onready var stats_component: StatsComponent = $StatsComponent
@onready var combat_manager: Node = get_node_or_null(combat_manager_path)

# 当前朝向后缀，对应动画中的 up/down/left/right
var facing_suffix: StringName = &"right"

# 玩家移动速度，单位是像素/秒。
@export var move_speed: float = 120.0
# 当前角色所属阵营，供子弹忽略友军与自身时读取。
@export_enum("玩家", "怪物", "中立") var faction: int = SHARED_ENUMS.Faction.PLAYER
# 按住攻击键时，两次开火之间的最小间隔。
@export_range(0.01, 2.0, 0.01) var attack_interval: float = 0.15
# 与怪物接近时的轻推强度。
@export var soft_push_strength: float = 14.0
# 与怪物发生软推时的作用距离。
@export var soft_push_radius: float = 20.0
# 战斗管理器路径，技能运行时通过它提交通用发射请求。
@export var combat_manager_path: NodePath = NodePath("../../CombatManager")
# 技能槽配置，按顺序对应：普攻、技能1、技能2、技能3、技能4。
@export var skill_definitions: Array[SkillDefinition] = [
	DEFAULT_BASIC_ATTACK_SKILL,
	DEFAULT_SKILL_1,
	DEFAULT_SKILL_2,
	DEFAULT_SKILL_3,
	DEFAULT_SKILL_4,
]

# 当前朝向
var facing_direction := Vector2.RIGHT
signal died

# 为每个方向预设不同的枪口偏移
var muzzle_offsets := {
	"down": Vector2(0.5, 13),
	"up": Vector2(0.5, -11.0),
	"left": Vector2(-10.0, 5.5),
	"right": Vector2(10.0, 5.5),
}

var _virtual_move_input: Vector2 = Vector2.ZERO
var _skill_slots: Array[SkillSlotRuntime] = []

func _ready() -> void:
	collision_layer = PHYSICS_LAYERS.PLAYER_BODY_LAYER_BIT
	collision_mask = PHYSICS_LAYERS.PLAYER_BODY_MASK
	if stats_component != null and not stats_component.died.is_connected(_on_stats_died):
		stats_component.died.connect(_on_stats_died)
	_setup_skill_slots()
	_update_armed_effect()
	_update_animation()

func apply_configured_skill_definitions(definitions: Array[SkillDefinition]) -> void:
	skill_definitions = definitions.duplicate()

func _physics_process(delta: float) -> void:
	if stats_component != null and stats_component.is_dead():
		_update_armed_effect()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_tick_skill_slots(delta)

	# 读取四个方向输入，并得到标准化后的八向输入向量
	var move_input: Vector2 = get_combined_move_input()

	# 先关闭玩家侧软推，避免与怪物离散等待/让行逻辑互相拉扯。
	# CharactorBody2D 通过 velocity 配合 move_and_slide() 完成移动
	velocity = move_input * _get_move_speed()
	move_and_slide()

	if move_input != Vector2.ZERO:
		# 保存当前朝向
		facing_direction = move_input

	facing_suffix = _vector_to_facing_suffix(facing_direction)
	_update_animation()
	_handle_attack_input()

func _setup_skill_slots() -> void:
	_skill_slots = []
	var resolved_definitions: Array[SkillDefinition] = []
	for definition in skill_definitions:
		resolved_definitions.append(definition)
	while resolved_definitions.size() < SKILL_SLOT_4 + 1:
		resolved_definitions.append(null)
	for index in range(resolved_definitions.size()):
		var slot_runtime: SkillSlotRuntime = SKILL_SLOT_RUNTIME_SCRIPT.new()
		slot_runtime.setup(index, resolved_definitions[index])
		_skill_slots.append(slot_runtime)

func _tick_skill_slots(delta: float) -> void:
	for index in range(_skill_slots.size()):
		var slot_runtime := _skill_slots[index]
		if slot_runtime == null:
			continue
		var context := _build_skill_execution_context(index)
		slot_runtime.tick(delta, context)

func _build_skill_execution_context(slot_index: int) -> SkillExecutionContext:
	var context: SkillExecutionContext = SKILL_EXECUTION_CONTEXT_SCRIPT.new()
	context.caster = self
	context.combat_manager = combat_manager
	context.spawn_position = _get_muzzle_position()
	context.facing_direction = _get_fire_direction()
	context.faction = faction
	context.slot_index = slot_index
	return context

func _get_muzzle_position() -> Vector2:
	var offset: Vector2 = muzzle_offsets.get(String(facing_suffix), Vector2.ZERO)
	return global_position + offset

func _get_fire_direction() -> Vector2:
	var normalized_direction := facing_direction.normalized()
	if normalized_direction == Vector2.ZERO:
		return Vector2.RIGHT
	return normalized_direction

func _get_soft_push_offset() -> Vector2:
	if soft_push_strength <= 0.0 or soft_push_radius <= 0.0 or get_parent() == null:
		return Vector2.ZERO

	var push := Vector2.ZERO
	for sibling in get_parent().get_children():
		if sibling == self:
			continue
		if not sibling is CharacterBody2D:
			continue
		if sibling.collision_layer != PHYSICS_LAYERS.ENEMY_BODY_LAYER_BIT:
			continue

		var offset: Vector2 = global_position - sibling.global_position
		var distance: float = offset.length()
		if distance <= 0.0 or distance > soft_push_radius:
			continue

		push += offset.normalized() * (1.0 - distance / soft_push_radius)

	return push.normalized() * soft_push_strength if push != Vector2.ZERO else Vector2.ZERO

# 根据当前朝向拼出动画名，并在动画实际变化时再切换播放
func _update_animation() -> void:
	var animation_name := StringName("%s_%s" % [NORMAL_ANIMATION_PREFIX, facing_suffix])

	if not body_sprite.sprite_frames.has_animation(animation_name):
		push_warning("Missing player animation: %s" % animation_name)
		return

	if body_sprite.animation != animation_name:
		body_sprite.play(animation_name)
	_update_armed_effect()

# 将任意二维向量映射为四方向动画
# 对角输入会优先取绝对值更大的轴，避免在四方向动画里出现歧义
func _vector_to_facing_suffix(direction: Vector2) -> StringName:
	if abs(direction.x) >= abs(direction.y):
		return &"right" if direction.x > 0.0 else &"left"

	return &"down" if direction.y > 0.0 else &"up"

# 监听按键
func _handle_attack_input() -> void:
	var pressed_slot: int = _get_pressed_skill_slot()
	if pressed_slot == INVALID_SKILL_SLOT:
		return
	trigger_skill_slot(pressed_slot)

func _get_pressed_skill_slot() -> int:
	if Input.is_action_pressed(ACTION_NORMAL_ATTACK):
		return SKILL_SLOT_BASIC_ATTACK
	if Input.is_action_pressed(ACTION_SKILL_1):
		return SKILL_SLOT_1
	if Input.is_action_pressed(ACTION_SKILL_2):
		return SKILL_SLOT_2
	if Input.is_action_pressed(ACTION_SKILL_3):
		return SKILL_SLOT_3
	if Input.is_action_pressed(ACTION_SKILL_4):
		return SKILL_SLOT_4
	return INVALID_SKILL_SLOT

func _get_move_speed() -> float:
	if stats_component == null:
		return move_speed
	var stat_move_speed: float = stats_component.get_stat(STAT_IDS.MOVE_SPEED)
	return stat_move_speed if stat_move_speed > 0.0 else move_speed

func get_attack_cooldown_interval() -> float:
	if stats_component == null:
		return attack_interval
	var attack_speed: float = stats_component.get_stat(STAT_IDS.ATTACK_SPEED)
	if attack_speed <= 0.0:
		return attack_interval
	return attack_interval / attack_speed

func set_virtual_move_input(input_vector: Vector2) -> void:
	_virtual_move_input = input_vector.limit_length(1.0)

func trigger_skill_slot(slot_index: int) -> bool:
	if is_dead():
		return false
	var slot_runtime := _get_skill_slot_runtime(slot_index)
	if slot_runtime == null:
		return false
	var cast_result: bool = slot_runtime.try_cast(_build_skill_execution_context(slot_index))
	if cast_result:
		_update_armed_effect()
	return cast_result

func _get_skill_slot_runtime(slot_index: int) -> SkillSlotRuntime:
	if slot_index < 0 or slot_index >= _skill_slots.size():
		return null
	return _skill_slots[slot_index]

func get_skill_slot_cooldown_data(slot_index: int) -> Dictionary:
	var slot_runtime := _get_skill_slot_runtime(slot_index)
	if slot_runtime == null:
		return {"remaining": 0.0, "duration": 0.0}
	return slot_runtime.get_cooldown_data()

func is_dead() -> bool:
	return stats_component != null and stats_component.is_dead()

func get_combined_move_input() -> Vector2:
	var keyboard_input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _virtual_move_input == Vector2.ZERO:
		return keyboard_input
	if keyboard_input == Vector2.ZERO:
		return _virtual_move_input
	return (keyboard_input + _virtual_move_input).limit_length(1.0)

func is_skill_slot_active(slot_index: int) -> bool:
	var slot_runtime := _get_skill_slot_runtime(slot_index)
	return slot_runtime != null and slot_runtime.is_active()

func _update_armed_effect() -> void:
	if armed_effect_sprite == null:
		return
	var is_armed: bool = is_skill_slot_active(SKILL_SLOT_4) and not is_dead()
	armed_effect_sprite.visible = is_armed
	if not is_armed:
		return
	var armed_animation := StringName("%s_%s" % [ARMED_ANIMATION_PREFIX, facing_suffix])
	if armed_effect_sprite.sprite_frames.has_animation(armed_animation) and armed_effect_sprite.animation != armed_animation:
		armed_effect_sprite.play(armed_animation)

func _on_stats_died(_source: Node, _context: Dictionary) -> void:
	_update_armed_effect()
	died.emit()
