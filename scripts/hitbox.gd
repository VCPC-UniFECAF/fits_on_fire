extends Area2D

@export var damage: int = 10
@export var knockback: float = 0.0
@export var lifetime: float = 0.15

var _owner_player: Node2D
var _hit_targets: Array = []


func _ready() -> void:
	add_to_group("player_attack")
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	monitoring = true
	if lifetime > 0.0:
		await get_tree().create_timer(lifetime).timeout
		queue_free()


func setup(owner_player: Node2D, dmg: int, life: float = 0.15, kb: float = 0.0) -> void:
	_owner_player = owner_player
	damage = dmg
	lifetime = life
	knockback = kb


func _on_area_entered(area: Area2D) -> void:
	if area == self:
		return
	var target := _resolve_target(area)
	if target and target not in _hit_targets:
		_apply_damage(target)


func _on_body_entered(body: Node2D) -> void:
	var target := _resolve_target(body)
	if target and target not in _hit_targets:
		_apply_damage(target)


func _resolve_target(node: Node) -> Node:
	if node.has_method("take_damage") and (node.is_in_group("enemy") or node.is_in_group("boss")):
		return node
	var parent := node.get_parent()
	if parent and parent.has_method("take_damage") and (parent.is_in_group("enemy") or parent.is_in_group("boss")):
		return parent
	return null


func _apply_damage(target: Node) -> void:
	_hit_targets.append(target)
	target.take_damage(damage, _owner_player, knockback)
