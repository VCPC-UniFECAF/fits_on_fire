extends Node

var _arrival_portal_id: String = ""


func _ready() -> void:
	var tree := get_tree()
	if tree:
		tree.scene_changed.connect(_on_scene_changed)


func set_travel(arrival_portal_id: String) -> void:
	_arrival_portal_id = arrival_portal_id


func _on_scene_changed() -> void:
	call_deferred("_apply_arrival_spawn_deferred")


func _apply_arrival_spawn_deferred() -> void:
	if _arrival_portal_id.is_empty():
		return
	await get_tree().process_frame
	apply_arrival_spawn()


func apply_arrival_spawn() -> void:
	if _arrival_portal_id.is_empty():
		return

	var portal := _find_portal_by_id(_arrival_portal_id)
	if portal == null:
		push_warning(
			"PortalTravel: portal '%s' não encontrado na cena." % _arrival_portal_id
		)
		_clear_travel()
		return

	if not portal.has_method("get_spawn_position_for_player"):
		push_warning(
			"PortalTravel: portal '%s' sem get_spawn_position_for_player." % _arrival_portal_id
		)
		_clear_travel()
		return

	for node in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(node) or not node is Node2D:
			continue
		if node.has_method("is_alive") and not node.is_alive():
			continue
		var pid: int = 0
		if "player_id" in node:
			pid = node.player_id
		node.global_position = portal.get_spawn_position_for_player(pid)

	if portal.has_method("start_arrival_cooldown"):
		portal.start_arrival_cooldown()

	_clear_travel()


func _find_portal_by_id(id: String) -> Node:
	for node in get_tree().get_nodes_in_group("portal"):
		if not is_instance_valid(node):
			continue
		if "portal_id" in node and node.portal_id == id:
			return node
	return null


func _clear_travel() -> void:
	_arrival_portal_id = ""
