extends CharacterBody2D

const SPEED: float = 180.0
const STATE_IDLE: StringName = &"idle"
const STATE_RUN: StringName = &"run"
const STATE_ATTACK: StringName = &"attack"
const IDLE_BLEND_PATH: String = "parameters/StateMachine/idle/BlendSpace2D/blend_position"
const RUN_BLEND_PATH: String = "parameters/StateMachine/run/BlendSpace2D/blend_position"
const ATTACK_BLEND_PATHS: Array[String] = [
	"parameters/StateMachine/attack/attack1/blend_position",
	"parameters/StateMachine/attack/attack2/blend_position",
	"parameters/StateMachine/attack/attack3/blend_position",
]
const CONDITION_TO_IDLE: String = "parameters/StateMachine/conditions/to_idle"
const CONDITION_TO_RUN: String = "parameters/StateMachine/conditions/to_run"
const CONDITION_TO_ATTACK: String = "parameters/StateMachine/conditions/to_attack"
const TOP_LEVEL_CONDITION_PATHS: Array[String] = [
	CONDITION_TO_IDLE,
	CONDITION_TO_RUN,
	CONDITION_TO_ATTACK,
]
const DIAGONAL_RELEASE_GRACE_TIME: float = 0.08
# 把所有需要同步方向的动画树路径集中在一起，
# 这样别的角色以后只要换掉路径配置，就能复用同一个视觉朝向 helper。
const VISUAL_BLEND_PATHS: Array[String] = [
	IDLE_BLEND_PATH,
	RUN_BLEND_PATH,
	ATTACK_BLEND_PATHS[0],
	ATTACK_BLEND_PATHS[1],
	ATTACK_BLEND_PATHS[2],
]

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_player: AnimationPlayer = $AnimationPlayer
# 顶层状态机只负责在待机、移动、攻击三大类状态之间切换。
@onready var animation_state: AnimationNodeStateMachinePlayback = animation_tree["parameters/StateMachine/playback"]
# attack 子状态机只负责决定当前进入 attack1、attack2 还是 attack3。
@onready var attack_state: AnimationNodeStateMachinePlayback = animation_tree["parameters/StateMachine/attack/playback"]
@onready var sprite: Sprite2D = $Sprite2D
# 这里把“左右翻转 + BlendSpace 方向同步”抽成公共能力，
# 这样 player 只保留玩家自己的输入和战斗逻辑。
@onready var visual_direction_helper := CharacterVisualDirectionHelper.new(sprite, animation_tree, VISUAL_BLEND_PATHS)

# 不移动时也要记住角色最后一次朝向，这样待机和攻击才能沿用正确方向。
var input_direction: Vector2 = Vector2.DOWN
# 只要处于攻击状态，就不允许移动逻辑覆盖当前动作。
var is_attacking: bool = false
# 顶层 attack 退出改成 At End 后并不稳定，
# 这里继续保留单段攻击时长，确保脚本能在正确时机解除攻击锁。
var attack_time_left: float = 0.0
# 攻击期间先只缓存出口目标，等顶层真正进入 attack 后再把条件切到 idle 或 run，
# 避免刚按下攻击的那一帧就被退出条件把 attack 抢回去。
var attack_exit_condition_path: String = CONDITION_TO_IDLE
# 记录最近一次明确的斜向输入，用来吸收玩家松手时两个方向键不同步带来的瞬时抖动。
var last_diagonal_direction: Vector2 = Vector2.ZERO
var diagonal_release_grace_left: float = 0.0

# 初始化动画树和默认朝向，保证角色一进场就处于正确的待机状态。
func _ready() -> void:
	animation_tree.active = true
	_update_visual_direction(input_direction)
	_clear_top_level_conditions()

# 每帧先统一处理输入和状态优先级，再决定是攻击分支还是移动分支。
func _physics_process(delta: float) -> void:
	var movement := _get_movement_input()
	_update_input_direction(movement, delta)

	# 这一层先处理攻击，是为了让攻击成为更高优先级状态，
	# 避免同一帧里移动动画又把攻击动画顶掉。
	if _try_start_attack():
		_process_attack(delta, movement)
		return

	if is_attacking:
		_process_attack(delta, movement)
		return

	_process_movement(movement)

# 把项目输入映射统一收口在这里，后面如果要接手柄或别的输入源更容易改。
func _get_movement_input() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")

# 只在可移动时更新朝向，避免攻击期间被新的移动输入改掉出招方向。
# 这里额外给斜向输入留一个很短的缓冲时间，避免玩家先松开一个方向键时，
# 最后一帧朝向被瞬间改成纯横或纯竖，导致 idle 看起来像“丢了斜向”。
func _update_input_direction(movement: Vector2, delta: float) -> void:
	if is_attacking:
		return

	if movement == Vector2.ZERO:
		diagonal_release_grace_left = maxf(diagonal_release_grace_left - delta, 0.0)
		return

	if _is_diagonal_direction(movement):
		input_direction = movement
		last_diagonal_direction = movement
		diagonal_release_grace_left = DIAGONAL_RELEASE_GRACE_TIME
		_update_visual_direction(input_direction)
		return

		# 玩家刚从斜向松开到单轴时，通常只是两个按键没有同一时刻弹起。
		# 在很短的缓冲窗口内继续保留原斜向，可以让停下后的 idle 更符合手感。
	if diagonal_release_grace_left > 0.0 and _matches_diagonal_axis(movement, last_diagonal_direction):
		diagonal_release_grace_left = maxf(diagonal_release_grace_left - delta, 0.0)
		return

	input_direction = movement
	last_diagonal_direction = Vector2.ZERO
	diagonal_release_grace_left = 0.0
	_update_visual_direction(input_direction)

# 尝试进入攻击状态，并把“已在攻击中”也视为攻击分支继续执行。
func _try_start_attack() -> bool:
	if is_attacking:
		return true

	var attack_name := _get_attack_input_name()
	if attack_name == &"":
		return false

	_start_attack(attack_name)
	return true

# 这里单独收口攻击输入，是为了以后要改成连招、蓄力、技能栏映射时，
# 不用再去动攻击状态切换本身。
func _get_attack_input_name() -> StringName:
	if Input.is_action_just_pressed(&"attack1"):
		return &"attack1"
	if Input.is_action_just_pressed(&"attack2"):
		return &"attack2"
	if Input.is_action_just_pressed(&"attack3"):
		return &"attack3"
	return &""

# 进入攻击状态时同时切换顶层状态机和攻击子状态机，保持状态结构清晰。
func _start_attack(attack_name: StringName) -> void:
	is_attacking = true
	attack_time_left = _get_current_attack_duration()
	attack_exit_condition_path = CONDITION_TO_IDLE
	# 顶层 idle / run / attack 现在交给 condition + advance 控制，
	# 但 attack1 / attack2 / attack3 仍然保持“按哪个键进哪一段”的手动入口语义。
	_update_visual_direction(input_direction)
	attack_state.travel(attack_name)
	_set_top_level_condition(CONDITION_TO_ATTACK)

# 攻击处理单独拆出来，是为了把“锁移动 + 顶层状态机在动画尾部退出”封装成独立动作分支。
func _process_attack(delta: float, movement: Vector2) -> void:
	velocity = Vector2.ZERO
	move_and_slide()

	# 顶层状态机还没真正切到 attack 前，
	# 先继续保留 to_attack 条件，避免同一帧又被 to_idle / to_run 抢回去，导致攻击根本播不出来。
	if animation_state.get_current_node() != STATE_ATTACK:
		return

	# 顶层 attack -> idle/run 已经交给 At End transition，
	# 这里先根据当前是否还有移动输入，持续刷新攻击结束后要走的出口。
	_update_attack_exit_condition(movement)

	attack_time_left -= delta
	if attack_time_left <= 0.0:
		_finish_attack()

# 当前 attack 仍由脚本决定何时解锁，
# 顶层状态机只负责根据条件在 attack 结尾时切到 idle 或 run。
func _finish_attack() -> void:
	is_attacking = false
	attack_time_left = 0.0
	_update_visual_direction(input_direction)
	_apply_attack_exit_condition()

# 移动分支只处理位移与 locomotion 动画，不和攻击逻辑混在一起。
func _process_movement(movement: Vector2) -> void:
	velocity = movement * SPEED
	move_and_slide()
	_update_locomotion_animation(movement)

# locomotion 只处理待机和移动，不负责攻击，
# 这样状态职责边界会更清楚，后面扩展翻滚、受击也更好拆分。
func _update_locomotion_animation(movement: Vector2) -> void:
	_update_visual_direction(input_direction)

	if movement == Vector2.ZERO:
		_set_top_level_condition(CONDITION_TO_IDLE)
		return

	_set_top_level_condition(CONDITION_TO_RUN)

# 顶层状态机现在改成由 condition 驱动，
# 所以每次切换前都要先清空旧条件，避免多个条件同时为 true 时抢状态。
func _clear_top_level_conditions() -> void:
	for condition_path in TOP_LEVEL_CONDITION_PATHS:
		animation_tree[condition_path] = false

# 对外统一只设置一个顶层状态切换条件，
# 这样 idle / run / attack 的状态决定仍然集中在 player 脚本里。
func _set_top_level_condition(condition_path: String) -> void:
	if is_attacking and condition_path != CONDITION_TO_ATTACK:
		attack_exit_condition_path = condition_path
		return

	_clear_top_level_conditions()
	animation_tree[condition_path] = true

# 攻击期间先缓存这次结束后该回 idle 还是 run，
# 真正写回顶层状态机要等脚本确认攻击结束后再做，
# 否则顶层 attack 还没播完就可能被提前切走。
func _update_attack_exit_condition(movement: Vector2) -> void:
	if movement == Vector2.ZERO:
		attack_exit_condition_path = CONDITION_TO_IDLE
	else:
		attack_exit_condition_path = CONDITION_TO_RUN

# 统一从缓存的攻击出口写回顶层状态机，
# 这样脚本和 AnimationTree 始终只认同一个退出目标。
func _apply_attack_exit_condition() -> void:
	_clear_top_level_conditions()
	animation_tree[attack_exit_condition_path] = true

# 当前攻击方向名仍然跟随真实输入方向，
# 这样 attack 播放和方向资源的对应关系不会被顶层状态切换方式影响。
func _get_current_attack_duration() -> float:
	var animation_name := _get_directional_attack_animation_name()
	if not animation_player.has_animation(animation_name):
		return 0.1

	var animation := animation_player.get_animation(animation_name)
	if animation == null:
		return 0.1

	return animation.length

# 当前攻击方向名仍然跟随真实输入方向，
# 这样 attack 播放和方向资源的对应关系不会被顶层状态切换方式影响。
func _get_directional_attack_animation_name() -> StringName:
	var horizontal_strength := absf(input_direction.x)
	var vertical_strength := absf(input_direction.y)

	if horizontal_strength > 0.1 and vertical_strength > 0.1:
		if input_direction.y < 0.0:
			return &"attack_right_up"
		return &"attack_right_down"

	if input_direction.y < -0.5:
		return &"attack_up"
	if input_direction.y > 0.5:
		return &"attack_down"
	return &"attack_right"

# player 自己只保留一个视觉方向入口，
# 具体怎么翻转精灵、怎么写动画树参数，交给公共 helper 处理。
func _update_visual_direction(direction: Vector2) -> void:
	visual_direction_helper.apply(direction)

func _is_diagonal_direction(direction: Vector2) -> bool:
	return absf(direction.x) > 0.1 and absf(direction.y) > 0.1

func _matches_diagonal_axis(direction: Vector2, diagonal_direction: Vector2) -> bool:
	if diagonal_direction == Vector2.ZERO:
		return false

	return signf(direction.x) == signf(diagonal_direction.x) or signf(direction.y) == signf(diagonal_direction.y)
