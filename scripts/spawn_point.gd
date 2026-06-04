class_name SpawnPoint
extends Marker2D

@export var enemy_scene_override: PackedScene
## Quando true, este ponto só é usado via spawn_point_index fixo (ex.: boss).
@export var exclude_from_rotation: bool = false


func _ready() -> void:
	add_to_group("spawn_point")


func spawn(scene: PackedScene, parent: Node) -> Node:
	var enemy := scene.instantiate()
	var spawn_pos := global_position
	parent.call_deferred("add_child", enemy)
	enemy.call_deferred("set_global_position", spawn_pos)
	return enemy
