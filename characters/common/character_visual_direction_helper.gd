class_name CharacterVisualDirectionHelper
extends RefCounted

# 这个辅助类只负责角色的视觉朝向同步，不接管输入、移动或攻击状态。
var sprite: Sprite2D
var animation_tree: AnimationTree
# 这里保存所有需要同步方向的 BlendSpace 参数路径，
# 这样不同角色只要传入自己的路径配置就能复用同一套逻辑。
var blend_paths: Array[String]

func _init(target_sprite: Sprite2D, target_animation_tree: AnimationTree, target_blend_paths: Array[String]) -> void:
	sprite = target_sprite
	animation_tree = target_animation_tree
	blend_paths = target_blend_paths.duplicate()

# 对外统一只暴露一个入口，调用方不需要关心翻转和动画树写值的细节。
func apply(direction: Vector2) -> void:
	_update_facing(direction)
	_update_animation_direction(direction)

func _update_facing(direction: Vector2) -> void:
	if sprite == null or direction.x == 0.0:
		return

	sprite.flip_h = direction.x < 0.0

func _update_animation_direction(direction: Vector2) -> void:
	if animation_tree == null:
		return

	# 当前横向资源只有朝右版本，所以 BlendSpace 一律喂右向值，
	# 朝左时仅通过 Sprite2D 翻转来复用同一套横向动画帧。
	var blend_direction := Vector2(absf(direction.x), direction.y)
	for path in blend_paths:
		animation_tree[path] = blend_direction
