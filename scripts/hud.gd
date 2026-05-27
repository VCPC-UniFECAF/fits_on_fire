extends CanvasLayer

@onready var _bar_p1: HealthBar = $lifeplayer1
@onready var _bar_p2: HealthBar = $lifeplayer2


func _ready() -> void:
	await get_tree().process_frame
	_bind_players()


func _bind_players() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node is PlayerBase:
			var player := node as PlayerBase
			if player.player_id == 0:
				_bar_p1.bind_player(player)
			elif player.player_id == 1:
				_bar_p2.bind_player(player)
