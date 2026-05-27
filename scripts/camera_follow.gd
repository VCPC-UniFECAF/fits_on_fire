extends Camera2D

@export var smooth_speed: float = 5.0
@export var zoom_speed: float = 3.0
@export var min_zoom: float = 1.0
@export var max_zoom: float = 2.0
@export var zoom_distance_max: float = 280.0
@export var max_player_distance: float = 280.0

var _player1: PlayerBase
var _player2: PlayerBase


func _ready() -> void:
	make_current()
	_refresh_players()


func get_max_player_distance() -> float:
	return max_player_distance


func _refresh_players() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node is PlayerBase:
			var player := node as PlayerBase
			if player.player_id == 0:
				_player1 = player
			elif player.player_id == 1:
				_player2 = player


func _process(delta: float) -> void:
	if not is_instance_valid(_player1) or not is_instance_valid(_player2):
		_refresh_players()

	var targets: Array[Vector2] = []
	var alive_p1: PlayerBase
	var alive_p2: PlayerBase

	if is_instance_valid(_player1) and _player1.is_alive():
		targets.append(_player1.global_position)
		alive_p1 = _player1
	if is_instance_valid(_player2) and _player2.is_alive():
		targets.append(_player2.global_position)
		alive_p2 = _player2

	if targets.is_empty():
		return

	var average_pos := Vector2.ZERO
	for pos in targets:
		average_pos += pos
	average_pos /= targets.size()

	global_position = global_position.lerp(average_pos, smooth_speed * delta)

	if targets.size() > 1 and alive_p1 and alive_p2:
		var dist_x := absf(alive_p1.global_position.x - alive_p2.global_position.x)
		var dist_y := absf(alive_p1.global_position.y - alive_p2.global_position.y)
		var screen_size := get_viewport_rect().size
		var aspect_ratio := screen_size.x / screen_size.y
		var effective_distance := maxf(dist_x, dist_y * aspect_ratio)
		var target_zoom_val := _map_range(
			effective_distance, 0.0, zoom_distance_max, max_zoom, min_zoom
		)
		var target_zoom := Vector2(target_zoom_val, target_zoom_val)
		zoom = zoom.lerp(target_zoom, zoom_speed * delta)
	else:
		var default_zoom := Vector2(max_zoom, max_zoom)
		zoom = zoom.lerp(default_zoom, zoom_speed * delta)


func _map_range(value: float, low1: float, high1: float, low2: float, high2: float) -> float:
	if is_equal_approx(high1, low1):
		return low2
	var res := low2 + (value - low1) * (high2 - low2) / (high1 - low1)
	return clampf(res, minf(low2, high2), maxf(low2, high2))
