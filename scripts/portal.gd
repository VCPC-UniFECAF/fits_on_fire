extends Area2D

@export_file("*.tscn") var next_level_path: String
@export var portal_id: String = ""
@export var destination_portal_id: String = ""

var _transitioning: bool = false
var _warned_missing_path: bool = false
var _warned_missing_destination: bool = false
var _arrival_cooldown: float = 0.0


func _ready() -> void:
	add_to_group("portal")
	collision_layer = 0
	collision_mask = 1
	monitoring = true


func _physics_process(delta: float) -> void:
	if _arrival_cooldown > 0.0:
		_arrival_cooldown -= delta
		return
	_try_transition()


func start_arrival_cooldown(duration: float = 0.5) -> void:
	_arrival_cooldown = duration


func get_spawn_position_for_player(player_id: int) -> Vector2:
	var marker := get_node_or_null("PlayerSpawn%d" % player_id) as Marker2D
	if marker:
		return marker.global_position
	push_warning("Portal '%s': falta PlayerSpawn%d." % [portal_id, player_id])
	return global_position


func _is_valid_player(body: Node) -> bool:
	if not body.is_in_group("player"):
		return false
	if body.has_method("is_alive") and not body.is_alive():
		return false
	return true


func _get_living_players() -> Array[Node2D]:
	var living: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(node) or not node is Node2D:
			continue
		if node.has_method("is_alive") and not node.is_alive():
			continue
		living.append(node)
	return living


func _get_players_inside() -> Dictionary:
	if not monitoring:
		return {}
	var inside: Dictionary = {}
	for body in get_overlapping_bodies():
		if _is_valid_player(body):
			inside[body.get_instance_id()] = body
	return inside


func _all_living_players_inside() -> bool:
	var required := _get_living_players()
	if required.is_empty():
		return false
	var inside := _get_players_inside()
	for player in required:
		if not inside.has(player.get_instance_id()):
			return false
	return true


func _has_living_enemies() -> bool:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_alive"):
			if enemy.is_alive():
				return true
		elif "is_alive" in enemy and enemy.is_alive:
			return true
		elif "health" in enemy and enemy.health > 0:
			return true
	return false


func _record_travel() -> void:
	if destination_portal_id.is_empty():
		if not _warned_missing_destination:
			push_warning(
				"Portal '%s': destination_portal_id não configurado." % portal_id
			)
			_warned_missing_destination = true
		return
	PortalTravel.set_travel(destination_portal_id)


func _try_transition() -> void:
	if _transitioning:
		return
	if not _all_living_players_inside():
		return
	if next_level_path.is_empty():
		if not _warned_missing_path:
			push_warning("Portal: next_level_path não configurado.")
			_warned_missing_path = true
		return
	if _has_living_enemies():
		return
	_transitioning = true
	_record_travel()
	var current_scene := get_tree().current_scene
	if current_scene and not current_scene.scene_file_path.is_empty():
		var scene_transition := get_tree().root.get_node_or_null("SceneTransition")
		if scene_transition:
			scene_transition.begin_transition(current_scene.scene_file_path)
	get_tree().call_deferred("change_scene_to_file", next_level_path)
