extends Area2D

const ATTACK_MULTIPLIER := 1.25
const StoryStateScript = preload("res://scripts/story_state.gd")

@export var powerup_both_player: bool = true


func _ready() -> void:
	collision_mask = 1
	monitoring = true
	var story := get_node_or_null("/root/StoryState") as StoryStateScript
	if story == null:
		return
	var scene := get_tree().current_scene
	if scene and story.is_power_up_collected(scene.scene_file_path):
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("is_alive") and not body.is_alive():
		return

	var story := get_node_or_null("/root/StoryState") as StoryStateScript
	if story == null:
		queue_free()
		return

	var scene := get_tree().current_scene
	var scene_path := scene.scene_file_path if scene else ""
	if story.collect_power_up(scene_path, ATTACK_MULTIPLIER):
		_sync_players_attack_multiplier(story)

	queue_free()


func _sync_players_attack_multiplier(story: StoryStateScript) -> void:
	var mult := story.get_attack_power_multiplier()
	for node in get_tree().get_nodes_in_group("player"):
		if node is PlayerBase:
			node.attack_multiplier = mult
