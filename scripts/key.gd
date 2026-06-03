extends Area2D

const StoryStateScript = preload("res://scripts/story_state.gd")


func _ready() -> void:
	collision_mask = 1
	monitoring = true
	var story := get_node_or_null("/root/StoryState") as StoryStateScript
	if story and story.cave_key_collected:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("is_alive") and not body.is_alive():
		return

	var story := get_node_or_null("/root/StoryState") as StoryStateScript
	if story:
		story.collect_cave_key()

	queue_free()
