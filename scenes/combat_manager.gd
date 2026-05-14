extends Node

@export var bullet_tscn: PackedScene
@onready var bullet_container: Node2D = $"../BulletContainer"

func _ready() -> void:
	# 找到玩家并连接信号
	var player = get_tree().current_scene.get_node("Player")
	player.attack_performed.connect(_on_player_attack)

func _on_player_attack(muzzle_position: Vector2, direction: Vector2) -> void:
	var bullet = bullet_tscn.instantiate()
	bullet.global_position = muzzle_position
	bullet.direction = direction
	bullet_container.add_child(bullet)
	
