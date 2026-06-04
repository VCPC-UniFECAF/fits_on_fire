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

@export var waves: Array[WaveConfig] = []
@export var spawn_points: Array[SpawnPoint] = []
@export var auto_collect_spawn_points: bool = true
@export var wave_advance_mode: WaveAdvanceMode = WaveAdvanceMode.CLEAR_ALL
@export var delay_between_waves: float = 2.0
@export var one_shot: bool = true

var _resolved_points: Array[SpawnPoint] = []
var _rotation_points: Array[SpawnPoint] = []
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
		_build_rotation_points()
		return
	if not auto_collect_spawn_points:
		return
	_resolved_points.append_array(_find_spawn_point_children(self))
	if not _resolved_points.is_empty():
		_build_rotation_points()
		return
	var scene_root := get_parent()
	if scene_root == null:
		return
	for node in get_tree().get_nodes_in_group("spawn_point"):
		if node is SpawnPoint and node.get_parent() == scene_root:
			_resolved_points.append(node)
	_build_rotation_points()


func _build_rotation_points() -> void:
	_rotation_points.clear()
	for point in _resolved_points:
		if not point.exclude_from_rotation:
			_rotation_points.append(point)


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
	if _rotation_points.is_empty():
		push_error("EnemySpawner: nenhum SpawnPoint disponível para rotação.")
		return _resolved_points[0]
	var point := _rotation_points[_point_index % _rotation_points.size()]
	_point_index += 1
	return point


func _get_spawn_point_for_entry(entry: WaveSpawnEntry) -> SpawnPoint:
	if entry.spawn_point_index >= 0 and entry.spawn_point_index < _resolved_points.size():
		return _resolved_points[entry.spawn_point_index]
	return _get_next_spawn_point()


func _resolve_scene(point: SpawnPoint, entry: WaveSpawnEntry) -> PackedScene:
	if entry.spawn_point_index >= 0 and entry.enemy_scene != null:
		return entry.enemy_scene
	if point.enemy_scene_override != null:
		return point.enemy_scene_override
	return entry.enemy_scene


func _has_any_override() -> bool:
	for point in _resolved_points:
		if point.enemy_scene_override != null:
			return true
	return false


func _entry_delay(entry: WaveSpawnEntry, wave: WaveConfig) -> float:
	if entry.delay_between_spawns >= 0.0:
		return entry.delay_between_spawns
	return wave.delay_between_spawns


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
			await _wait_before_next_wave(wave)
	if _running:
		all_waves_completed.emit()
	_running = false


func _spawn_wave(wave: WaveConfig) -> void:
	if wave.delay_before_wave > 0.0:
		await get_tree().create_timer(wave.delay_before_wave).timeout
		if not _running:
			return

	if wave.entries.is_empty():
		push_warning("EnemySpawner: onda '%s' sem entries." % _wave_label(wave))
		return

	var has_scene := false
	for entry in wave.entries:
		if entry != null and entry.enemy_scene != null:
			has_scene = true
			break
	if not has_scene and not _has_any_override():
		push_warning("EnemySpawner: onda '%s' sem enemy_scene." % _wave_label(wave))

	for entry in wave.entries:
		if not _running:
			return
		if entry == null:
			continue
		await _spawn_entry(entry, wave)


func _spawn_entry(entry: WaveSpawnEntry, wave: WaveConfig) -> void:
	var spawn_delay := _entry_delay(entry, wave)
	for i in entry.count:
		if not _running:
			return
		var point := _get_spawn_point_for_entry(entry)
		var scene := _resolve_scene(point, entry)
		if scene == null:
			push_warning("EnemySpawner: cena de inimigo não definida.")
			continue
		var enemy := point.spawn(scene, _get_spawn_parent())
		if enemy:
			_spawned.append(enemy)
		if i < entry.count - 1 and spawn_delay > 0.0:
			await get_tree().create_timer(spawn_delay).timeout


func _wave_delay_after(wave: WaveConfig) -> float:
	if wave.delay_after_wave >= 0.0:
		return wave.delay_after_wave
	return delay_between_waves


func _resolve_advance_mode(wave: WaveConfig) -> WaveAdvanceMode:
	match wave.advance_mode:
		WaveConfig.AdvanceMode.DELAY:
			return WaveAdvanceMode.DELAY
		WaveConfig.AdvanceMode.CLEAR_ALL:
			return WaveAdvanceMode.CLEAR_ALL
		WaveConfig.AdvanceMode.BOTH:
			return WaveAdvanceMode.BOTH
		_:
			return wave_advance_mode


func _wait_before_next_wave(wave: WaveConfig) -> void:
	if not _running:
		return
	var mode := _resolve_advance_mode(wave)
	var pause := _wave_delay_after(wave)
	match mode:
		WaveAdvanceMode.DELAY:
			await get_tree().create_timer(pause).timeout
		WaveAdvanceMode.CLEAR_ALL:
			await _wait_until_clear()
		WaveAdvanceMode.BOTH:
			var start_ms := Time.get_ticks_msec()
			await _wait_until_clear()
			var elapsed := (Time.get_ticks_msec() - start_ms) / 1000.0
			var remaining := pause - elapsed
			if remaining > 0.0:
				await get_tree().create_timer(remaining).timeout


func _wait_until_clear() -> void:
	_prune_spawned()
	while _running and _count_living_spawned() > 0:
		await get_tree().create_timer(0.25).timeout
		_prune_spawned()


func _wave_label(wave: WaveConfig) -> String:
	if not wave.display_name.is_empty():
		return wave.display_name
	return "Wave"
