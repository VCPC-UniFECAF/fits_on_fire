class_name SpawnPoint
extends Marker2D

@export var enemy_scene_override: PackedScene


func _ready() -> void:
	add_to_group("spawn_point")


func spawn(scene: PackedScene, parent: Node) -> Node:
	var enemy := scene.instantiate()
	var spawn_pos := global_position
	parent.call_deferred("add_child", enemy)
	enemy.call_deferred("set_global_position", spawn_pos)
	return enemy
