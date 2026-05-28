class_name EnemySpawner
extends Node2D

enum WaveAdvanceMode {
	DELAY,
	CLEAR_ALL,
	BOTH,
}

signal wave_started(wave_index: int)
signal wave_completed(wave_index: int)
signal all_waves_completed

@export var waves: Array[EnemyWave] = []
@export var spawn_points: Array[SpawnPoint] = []
@export var auto_collect_spawn_points: bool = true
@export var wave_advance_mode: WaveAdvanceMode = WaveAdvanceMode.CLEAR_ALL
@export var delay_between_waves: float = 2.0
@export var one_shot: bool = true

var _resolved_points: Array[SpawnPoint] = []
var _spawned: Array[Node] = []
var _point_index: int = 0
var _running: bool = false
var _started: bool = false


func start() -> void:
	if one_shot and _started:
		return
	if _running:
		return
	_resolve_spawn_points()
	if _resolved_points.is_empty():
		push_error("EnemySpawner: nenhum SpawnPoint encontrado.")
		return
	if waves.is_empty():
		push_warning("EnemySpawner: lista de ondas vazia.")
		return
	_started = true
	_running = true
	_point_index = 0
	_run_waves_async()


func stop() -> void:
	_running = false


func _resolve_spawn_points() -> void:
	_resolved_points.clear()
	if not spawn_points.is_empty():
		for point in spawn_points:
			if point != null and is_instance_valid(point):
				_resolved_points.append(point)
		return
	if not auto_collect_spawn_points:
		return
	_resolved_points.append_array(_find_spawn_point_children(self))
	if not _resolved_points.is_empty():
		return
	var scene_root := get_parent()
	if scene_root == null:
		return
	for node in get_tree().get_nodes_in_group("spawn_point"):
		if node is SpawnPoint and node.get_parent() == scene_root:
			_resolved_points.append(node)


func _find_spawn_point_children(node: Node) -> Array[SpawnPoint]:
	var found: Array[SpawnPoint] = []
	for child in node.get_children():
		if child is SpawnPoint:
			found.append(child)
		found.append_array(_find_spawn_point_children(child))
	return found


func _get_spawn_parent() -> Node:
	return get_parent() if get_parent() else self


func _get_next_spawn_point() -> SpawnPoint:
	var point := _resolved_points[_point_index % _resolved_points.size()]
	_point_index += 1
	return point


func _resolve_scene(point: SpawnPoint, wave: EnemyWave) -> PackedScene:
	if point.enemy_scene_override != null:
		return point.enemy_scene_override
	return wave.enemy_scene


func _has_any_override() -> bool:
	for point in _resolved_points:
		if point.enemy_scene_override != null:
			return true
	return false


func _prune_spawned() -> void:
	var alive: Array[Node] = []
	for enemy in _spawned:
		if is_instance_valid(enemy):
			alive.append(enemy)
	_spawned = alive


func _count_living_spawned() -> int:
	var count := 0
	for enemy in _spawned:
		if not is_instance_valid(enemy):
			continue
		if enemy.get("is_alive") != null and enemy.is_alive:
			count += 1
	return count


func _run_waves_async() -> void:
	for wave_index in waves.size():
		if not _running:
			return
		var wave := waves[wave_index]
		if wave == null:
			continue
		wave_started.emit(wave_index)
		await _spawn_wave(wave)
		if not _running:
			return
		wave_completed.emit(wave_index)
		if wave_index < waves.size() - 1:
			await _wait_before_next_wave()
	if _running:
		all_waves_completed.emit()
	_running = false


func _spawn_wave(wave: EnemyWave) -> void:
	if wave.enemy_scene == null and not _has_any_override():
		push_warning("EnemySpawner: onda sem enemy_scene.")
	for i in wave.count:
		if not _running:
			return
		var point := _get_next_spawn_point()
		var scene := _resolve_scene(point, wave)
		if scene == null:
			push_warning("EnemySpawner: cena de inimigo não definida.")
			continue
		var enemy := point.spawn(scene, _get_spawn_parent())
		if enemy:
			_spawned.append(enemy)
		if i < wave.count - 1 and wave.delay_between_spawns > 0.0:
			await get_tree().create_timer(wave.delay_between_spawns).timeout


func _wait_before_next_wave() -> void:
	if not _running:
		return
	match wave_advance_mode:
		WaveAdvanceMode.DELAY:
			await get_tree().create_timer(delay_between_waves).timeout
		WaveAdvanceMode.CLEAR_ALL:
			await _wait_until_clear()
		WaveAdvanceMode.BOTH:
			var start_ms := Time.get_ticks_msec()
			await _wait_until_clear()
			var elapsed := (Time.get_ticks_msec() - start_ms) / 1000.0
			var remaining := delay_between_waves - elapsed
			if remaining > 0.0:
				await get_tree().create_timer(remaining).timeout


func _wait_until_clear() -> void:
	_prune_spawned()
	while _running and _count_living_spawned() > 0:
		await get_tree().create_timer(0.25).timeout
		_prune_spawned()
