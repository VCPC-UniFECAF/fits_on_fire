extends Node

signal lives_changed(player_id: int, remaining: int, max_lives: int)

const LIVES_SINGLE := 3
const LIVES_MULTI := 2
const DEATH_RELOAD_DELAY := 1.0
const EXTRALEVEL_SCENE := "res://scenes/extralevel.tscn"
const EXTRALEVEL_REVIVE_DELAY := 2.0
const REVIVE_PARTNER_OFFSET := Vector2(40, 0)

var _lives: Dictionary = {0: LIVES_MULTI, 1: LIVES_MULTI}
var _handling_death: bool = false
var _revive_generation: int = 0


func reset_for_new_game() -> void:
	var max_lives := get_max_lives()
	_lives[0] = max_lives
	_lives[1] = max_lives
	_emit_all()


func get_max_lives() -> int:
	if GameSession.mode == GameSession.Mode.SINGLE:
		return LIVES_SINGLE
	return LIVES_MULTI


func get_lives(player_id: int) -> int:
	return _lives.get(player_id, 0)


func consume_life(player_id: int) -> int:
	if _lives.get(player_id, 0) > 0:
		_lives[player_id] -= 1
	_emit_lives_changed(player_id)
	return _lives[player_id]


func all_players_exhausted() -> bool:
	if GameSession.mode == GameSession.Mode.SINGLE:
		return get_lives(0) <= 0
	return get_lives(0) <= 0 and get_lives(1) <= 0


func handle_player_death(player: PlayerBase) -> void:
	if _handling_death:
		return

	var remaining := consume_life(player.player_id)

	if GameSession.mode == GameSession.Mode.SINGLE:
		if remaining <= 0:
			_schedule_return_to_menu()
		else:
			_schedule_reload()
		return

	if all_players_exhausted():
		_schedule_return_to_menu()
		return

	if _is_extralevel() and remaining > 0 and _has_alive_partner(player):
		_schedule_extralevel_revive(player)
		return

	if _all_players_dead_in_scene():
		_schedule_reload()


func apply_to_player(player: PlayerBase) -> void:
	if get_lives(player.player_id) <= 0:
		player.die(false)


func _all_players_dead_in_scene() -> bool:
	var tree := get_tree()
	if tree == null:
		return false

	var found_player := false
	for node in tree.get_nodes_in_group("player"):
		if not node is PlayerBase:
			continue
		found_player = true
		if node.is_alive():
			return false

	return found_player


func _schedule_reload() -> void:
	if _handling_death:
		return
	_cancel_extralevel_revives()
	_handling_death = true
	_reload_after_delay()


func _schedule_return_to_menu() -> void:
	if _handling_death:
		return
	_cancel_extralevel_revives()
	_handling_death = true
	_return_to_menu_after_delay()


func _is_extralevel() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var scene := tree.current_scene
	return scene != null and scene.scene_file_path == EXTRALEVEL_SCENE


func _has_alive_partner(dead_player: PlayerBase) -> bool:
	for node in get_tree().get_nodes_in_group("player"):
		if node is PlayerBase and node != dead_player and node.is_alive():
			return true
	return false


func _get_partner_player(player: PlayerBase) -> PlayerBase:
	for node in get_tree().get_nodes_in_group("player"):
		if node is PlayerBase and node != player:
			return node
	return null


func _cancel_extralevel_revives() -> void:
	_revive_generation += 1


func _schedule_extralevel_revive(player: PlayerBase) -> void:
	var generation := _revive_generation
	_extralevel_revive_after_delay(player, generation)


func _extralevel_revive_after_delay(player: PlayerBase, generation: int) -> void:
	var tree := get_tree()
	if tree == null:
		return

	await tree.create_timer(EXTRALEVEL_REVIVE_DELAY).timeout

	if generation != _revive_generation:
		return
	if not is_instance_valid(player) or player.state != PlayerBase.State.DEAD:
		return
	if not _is_extralevel():
		return
	if get_lives(player.player_id) <= 0:
		return

	var partner := _get_partner_player(player)
	if partner == null:
		return

	var offset := REVIVE_PARTNER_OFFSET
	if player.player_id == 1:
		offset.x *= -1.0
	player.revive(partner.global_position + offset)


func _reload_after_delay() -> void:
	var tree := get_tree()
	if tree == null:
		_handling_death = false
		return

	await tree.create_timer(DEATH_RELOAD_DELAY).timeout
	PortalTravel.clear_travel()

	var scene := tree.current_scene
	if scene and not scene.scene_file_path.is_empty():
		tree.change_scene_to_file(scene.scene_file_path)

	_handling_death = false


func _return_to_menu_after_delay() -> void:
	var tree := get_tree()
	if tree == null:
		_handling_death = false
		return

	await tree.create_timer(DEATH_RELOAD_DELAY).timeout
	GameSession.return_to_menu()
	_handling_death = false


func _emit_lives_changed(player_id: int) -> void:
	lives_changed.emit(player_id, get_lives(player_id), get_max_lives())


func _emit_all() -> void:
	var max_lives := get_max_lives()
	lives_changed.emit(0, get_lives(0), max_lives)
	if GameSession.mode == GameSession.Mode.MULTI:
		lives_changed.emit(1, get_lives(1), max_lives)
