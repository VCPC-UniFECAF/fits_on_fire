class_name Wand
extends Node2D

const AIM_STICK_DEADZONE_SQ := 0.04
const AIM_MOUSE_MIN_DIST_SQ := 16.0

var aim_direction: Vector2 = Vector2.RIGHT

var _player: PlayerBase


func _ready() -> void:
	_player = get_parent() as PlayerBase


func _physics_process(_delta: float) -> void:
	if not _player or _player.state == PlayerBase.State.DEAD:
		return
	aim()


func aim() -> void:
	var aim_vec := _get_aim_vector()
	if aim_vec.length_squared() < 0.01:
		return

	aim_direction = aim_vec.normalized()
	rotation = aim_direction.angle()


func _get_aim_vector() -> Vector2:
	if not _player:
		return Vector2.ZERO

	var prefix := _player.get_input_prefix()
	var stick := Input.get_vector(
		prefix + "aim_left",
		prefix + "aim_right",
		prefix + "aim_up",
		prefix + "aim_down"
	)
	if stick.length_squared() > AIM_STICK_DEADZONE_SQ:
		return stick

	if _can_aim_with_mouse():
		var to_mouse := get_global_mouse_position() - _player.global_position
		if to_mouse.length_squared() > AIM_MOUSE_MIN_DIST_SQ:
			return to_mouse

	return Vector2.ZERO


func _can_aim_with_mouse() -> bool:
	if not _player:
		return false
	if _player.player_id == 1:
		return true
	var players := get_tree().get_nodes_in_group("player")
	if players.size() <= 1:
		return true
	return Input.get_connected_joypads().is_empty()


func get_muzzle_position(spawn_offset: float = 0.0) -> Vector2:
	if spawn_offset <= 0.0:
		return global_position
	return global_position + aim_direction * spawn_offset
