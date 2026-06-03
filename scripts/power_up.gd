extends Area2D

const ATTACK_MULTIPLIER := 1.25

@export var powerup_both_player: bool = true


func _ready() -> void:
	collision_mask = 1
	monitoring = true


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("is_alive") and not body.is_alive():
		return

	if powerup_both_player:
		_powerup_all_players()
	else:
		_apply_powerup(body as PlayerBase)

	queue_free()


func _apply_powerup(player: PlayerBase) -> void:
	if player == null or not player.is_alive():
		return
	player.apply_attack_power_up(ATTACK_MULTIPLIER)


func _powerup_all_players() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node is PlayerBase:
			_apply_powerup(node)
