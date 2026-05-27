extends Area2D

@export var damage: int = 5
@export var speed: float = 120.0
@export var lifetime: float = 1.0
@export var knockback: float = 0.0

var direction: Vector2 = Vector2.RIGHT
var _owner_player: Node2D
var _hit_targets: Array = []


func _ready() -> void:
	add_to_group("player_attack")
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(lifetime).timeout
	queue_free()


func setup(owner_player: Node2D, dir: Vector2, dmg: int, spd: float, life: float, kb: float = 0.0) -> void:
	_owner_player = owner_player
	direction = dir.normalized()
	damage = dmg
	speed = spd
	lifetime = life
	knockback = kb
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta


func _on_area_entered(area: Area2D) -> void:
	if area == self:
		return
	var target := _resolve_target(area)
	if target and target not in _hit_targets:
		_hit_targets.append(target)
		target.take_damage(damage, _owner_player, knockback)
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	var target := _resolve_target(body)
	if target and target not in _hit_targets:
		_hit_targets.append(target)
		target.take_damage(damage, _owner_player, knockback)
		queue_free()


func _resolve_target(node: Node) -> Node:
	if node.has_method("take_damage") and (node.is_in_group("enemy") or node.is_in_group("boss")):
		return node
	var parent := node.get_parent()
	if parent and parent.has_method("take_damage") and (parent.is_in_group("enemy") or parent.is_in_group("boss")):
		return parent
	return null
