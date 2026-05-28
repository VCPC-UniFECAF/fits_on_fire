class_name ActivateSpawn
extends Area2D

## Caminho até o EnemySpawner (ex.: ../EnemySpawner). Use o picker do Inspector se preferir.
@export var spawner_path: NodePath
@export var trigger_once: bool = true

var _spawner: EnemySpawner
var _triggered: bool = false


func _ready() -> void:
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)
	_resolve_spawner()


func _resolve_spawner() -> void:
	if _spawner != null and is_instance_valid(_spawner):
		return
	if not spawner_path.is_empty():
		_spawner = get_node_or_null(spawner_path) as EnemySpawner
	if _spawner == null:
		var parent_node := get_parent()
		if parent_node:
			_spawner = parent_node.get_node_or_null("EnemySpawner") as EnemySpawner
	if _spawner == null and not spawner_path.is_empty():
		push_warning(
			"ActivateSpawn: não encontrou EnemySpawner em '%s'." % spawner_path
		)


func _on_body_entered(body: Node2D) -> void:
	if _triggered and trigger_once:
		return
	if not body.is_in_group("player"):
		return
	if body.has_method("is_alive") and not body.is_alive():
		return
	_resolve_spawner()
	if _spawner == null:
		push_warning("ActivateSpawn: spawner não configurado.")
		return
	_spawner.start()
	if trigger_once:
		_triggered = true
		set_deferred("monitoring", false)
