extends Area2D

const SPEED: float = 360.0
const LIFETIME: float = 1.2

@onready var visible_on_screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

# 火球的朝向和速度由施法者在生成时注入，
# 这样这个投射物场景本身可以复用到别的角色技能上。
var direction: Vector2 = Vector2.DOWN
var lifetime_left: float = LIFETIME

func setup(target_direction: Vector2) -> void:
	direction = target_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN

func _ready() -> void:
	rotation = direction.angle()
	if not visible_on_screen_notifier.screen_exited.is_connected(_on_visible_on_screen_notifier_2d_screen_exited):
		visible_on_screen_notifier.screen_exited.connect(_on_visible_on_screen_notifier_2d_screen_exited)

func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta
	lifetime_left -= delta
	if lifetime_left <= 0.0:
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
