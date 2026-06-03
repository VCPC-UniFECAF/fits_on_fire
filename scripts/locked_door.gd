extends Area2D

const StoryStateScript = preload("res://scripts/story_state.gd")

@onready var _closed_layer: TileMapLayer = $"../TileMapLayer2"
@onready var _open_layer: TileMapLayer = $"../TileMapLayer3"


func _ready() -> void:
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)

	var story := get_node_or_null("/root/StoryState") as StoryStateScript
	if story and story.cave_gate_unlocked:
		_apply_gate_open(true)
		monitoring = false
	else:
		_apply_gate_open(false)


func _apply_gate_open(open: bool) -> void:
	if _closed_layer:
		_closed_layer.enabled = not open
	if _open_layer:
		_open_layer.enabled = open


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("is_alive") and not body.is_alive():
		return

	var story := get_node_or_null("/root/StoryState") as StoryStateScript
	if story == null or not story.cave_key_collected or story.cave_gate_unlocked:
		return

	story.unlock_cave_gate()
	_apply_gate_open(true)
	set_deferred("monitoring", false)
