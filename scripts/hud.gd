extends CanvasLayer

@onready var _bar_p1: HealthBar = $lifeplayer1
@onready var _bar_p2: HealthBar = $lifeplayer2


func _ready() -> void:
	_bar_p1.setup_lives(0)
	_bar_p2.setup_lives(1)
	call_deferred("_bind_players")


func set_multiplayer_hud(enabled: bool) -> void:
	_bar_p2.visible = enabled
	refresh_lives_display()


func refresh_players() -> void:
	_bind_players()


func refresh_lives_display() -> void:
	var max_lives := PlayerLives.get_max_lives()
	_bar_p1.set_lives_display(PlayerLives.get_lives(0), max_lives)
	if _bar_p2.visible:
		_bar_p2.set_lives_display(PlayerLives.get_lives(1), max_lives)


func _bind_players() -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group("player"):
		if node is PlayerBase:
			var player := node as PlayerBase
			if player.player_id == 0:
				_bar_p1.bind_player(player)
			elif player.player_id == 1 and _bar_p2.visible:
				_bar_p2.bind_player(player)
