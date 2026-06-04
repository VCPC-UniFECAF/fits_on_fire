extends Control

@onready var _main_menu: VBoxContainer = $CenterContainer/MainMenu
@onready var _character_select: VBoxContainer = $CenterContainer/CharacterSelect


func _ready() -> void:
	_show_main_menu()


func _show_main_menu() -> void:
	_main_menu.show()
	_character_select.hide()


func _on_single_player_pressed() -> void:
	_main_menu.hide()
	_character_select.show()


func _on_multiplayer_pressed() -> void:
	GameSession.start_multiplayer()


func _on_warrior_pressed() -> void:
	GameSession.start_single_player(GameSession.Character.WARRIOR)


func _on_wizard_pressed() -> void:
	GameSession.start_single_player(GameSession.Character.WIZARD)


func _on_back_pressed() -> void:
	_show_main_menu()


func _on_quit_pressed() -> void:
	get_tree().quit()
