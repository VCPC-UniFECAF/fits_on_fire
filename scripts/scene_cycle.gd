extends Node

const SCENE_ORDER: Array[String] = [
	"res://scenes/house.tscn",
	"res://scenes/woods.tscn",
	"res://scenes/forest.tscn",
	"res://scenes/ruins.tscn",
	"res://scenes/cave.tscn",
	"res://scenes/dragons_nest.tscn",
]

var _changing: bool = false


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)


func _on_scene_changed() -> void:
	_changing = false


func _input(event: InputEvent) -> void:
	if _changing or not event.is_action_pressed("cycle_scene"):
		return
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path == "res://scenes/menu.tscn":
		return
	get_viewport().set_input_as_handled()
	_go_to_next_scene()


func _go_to_next_scene() -> void:
	var current_path := ""
	var scene := get_tree().current_scene
	if scene and not scene.scene_file_path.is_empty():
		current_path = scene.scene_file_path
	var index := SCENE_ORDER.find(current_path)
	var next_index := 0 if index < 0 else (index + 1) % SCENE_ORDER.size()
	_changing = true
	get_tree().call_deferred("change_scene_to_file", SCENE_ORDER[next_index])
