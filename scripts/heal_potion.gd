extends Area2D

@export var heal_both_players: bool = true

func _ready() -> void:
	
	monitoring = true
	
	pass

func _on_body_entered(body: Node2D) -> void:
	
	if not body.is_in_group("player"):
		return
	
	if body.has_method("is_alive") and not body.is_alive():
		return
	
	if heal_both_players:
		_heal_all_players()
	else:
		_heal_player(body as PlayerBase)
	
	$CollisionShape2D.queue_free()
	queue_free()
	
	pass

func _heal_player(player: PlayerBase) -> void:
	
	if player == null or not player.is_alive():
		return
	player.health = player.max_health
	player.health_changed.emit(player.health, player.max_health)
	
pass

func _heal_all_players() -> void:
	
	for node in get_tree().get_nodes_in_group("player"):
		if node is PlayerBase:
			_heal_player(node)
	
pass
