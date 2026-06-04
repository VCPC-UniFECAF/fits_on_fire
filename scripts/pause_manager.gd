extends Node

const PAUSE_MENU_SCENE := preload("res://prefabs/pause_menu.tscn")
const MENU_SCENE := "res://scenes/menu.tscn"
const MAIN_SCENE := "res://scenes/main.tscn"

var _pause_ui: CanvasLayer
var _paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_ui = PAUSE_MENU_SCENE.instantiate()
	add_child(_pause_ui)
	_pause_ui.hide()
	var tree := get_tree()
	if tree:
		tree.scene_changed.connect(_on_scene_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause_menu"):
		return
	if _is_wise_dialog_open():
		return
	if not _is_gameplay_scene():
		return
	get_viewport().set_input_as_handled()
	if _paused:
		resume()
	else:
		pause()


func pause() -> void:
	if _paused or not _is_gameplay_scene():
		return
	_paused = true
	get_tree().paused = true
	_pause_ui.show()
	if _pause_ui.has_method("focus_default"):
		_pause_ui.call_deferred("focus_default")


func resume() -> void:
	if not _paused:
		return
	_paused = false
	get_tree().paused = false
	_pause_ui.hide()


func return_to_main_menu() -> void:
	resume()
	GameSession.return_to_menu()


func _on_scene_changed() -> void:
	if _paused:
		resume()


func _is_gameplay_scene() -> bool:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path.is_empty():
		return false
	var path := scene.scene_file_path
	if path == MENU_SCENE:
		return false
	return GameSession.LEVEL_SCENES.has(path) or path == MAIN_SCENE


func _is_wise_dialog_open() -> bool:
	for node in get_tree().get_nodes_in_group("wise"):
		if node.has_method("is_dialog_open") and node.is_dialog_open():
			return true
	return false
