class_name SpawnPoint
extends Marker2D

@export var enemy_scene_override: PackedScene


func _ready() -> void:
	add_to_group("spawn_point")


func spawn(scene: PackedScene, parent: Node) -> Node:
	var enemy := scene.instantiate()
	parent.add_child(enemy)
	enemy.global_position = global_position
	return enemy
