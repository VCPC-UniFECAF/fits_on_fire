extends Control

@onready var _main_menu: VBoxContainer = $CenterContainer/MainMenu
@onready var _character_select: VBoxContainer = $CenterContainer/CharacterSelect

var _main_menu_buttons: Array[Button] = []
var _character_select_buttons: Array[Button] = []


func _ready() -> void:
	_main_menu_buttons = UiMenuFocus.collect_buttons(_main_menu)
	_character_select_buttons = UiMenuFocus.collect_buttons(_character_select)
	UiMenuFocus.link_vertical(_main_menu_buttons)
	UiMenuFocus.link_vertical(_character_select_buttons)
	_show_main_menu()
	UiMenuFocus.grab_first(_main_menu_buttons)


func _unhandled_input(event: InputEvent) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	if UiMenuFocus.handle_confirm(event, vp):
		return
	if _character_select.visible and event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		vp.set_input_as_handled()


func _show_main_menu() -> void:
	_main_menu.show()
	_character_select.hide()
	UiMenuFocus.grab_first(_main_menu_buttons)


func _on_single_player_pressed() -> void:
	_main_menu.hide()
	_character_select.show()
	UiMenuFocus.grab_first(_character_select_buttons)


func _on_multiplayer_pressed() -> void:
	GameSession.start_multiplayer()


func _on_warrior_pressed() -> void:
	GameSession.start_single_player(GameSession.Character.WARRIOR)


func _on_wizard_pressed() -> void:
	GameSession.start_single_player(GameSession.Character.WIZARD)


func _on_back_pressed() -> void:
	_show_main_menu()
