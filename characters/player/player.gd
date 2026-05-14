extends CharacterBody2D
class_name Player

# 默认动画前缀
const NORMAL_ANIMATION_PREFIX := &"normal"

# 角色动画节点，负责播放四方形移动画
@onready var body_sprite: AnimatedSprite2D = $BodySprite

# 当前朝向后缀，对应动画中的 up/down/left/right
var facing_suffix: StringName = &"right"

# 玩家移动速度，单位是像素/秒。
@export var move_speed: float = 120.0

# 当前朝向
var facing_direction := Vector2.RIGHT  # 默认朝下
# 设置攻击信号
signal attack_performed(muzzle_position: Vector2, direction:Vector2)

func _ready() -> void:
	_update_animation()

func _physics_process(delta: float) -> void:
	# 读取四个方向输入，并得到标准化后的八向输入向量
	var move_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# CharactorBody2D 通过 velocity 配合 move_and_slide() 完成移动
	velocity = move_input * move_speed
	move_and_slide()
	
	if move_input != Vector2.ZERO:
		# 保存当前朝向
		facing_direction = move_input
	
	facing_suffix = _vector_to_facing_suffix(facing_direction)
	_update_animation()

# 根据当前朝向拼出动画名，并在动画实际变化时再切换播放
func _update_animation() -> void:
	var animation_name := StringName("%s_%s" % [NORMAL_ANIMATION_PREFIX, facing_suffix])
	
	if not body_sprite.sprite_frames.has_animation(animation_name):
		push_warning("Missing player animation: %s" % animation_name)
		return
		
	if body_sprite.animation != animation_name:
		body_sprite.play(animation_name)

# 将任意二维向量映射为四方向动画
# 对角输入会优先取绝对值更大的轴，避免在四方向动画里出现歧义
func _vector_to_facing_suffix(direction: Vector2) -> StringName:
	if abs(direction.x) >= abs(direction.y):
		return &"right" if direction.x > 0.0 else &"left"
	
	return &"down" if direction.y > 0.0 else &"up"

# 监听按键
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack1"):
		_try_attack()
		
# 攻击
func _try_attack() -> void:
	attack_performed.emit(global_position, facing_direction)
