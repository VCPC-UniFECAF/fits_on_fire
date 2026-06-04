extends CanvasLayer

@onready var _resume_button: Button = $Control/CenterContainer/VBoxContainer/ResumeButton
@onready var _menu_button: Button = $Control/CenterContainer/VBoxContainer/MenuButton

var _buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_buttons = [_resume_button, _menu_button]
	UiMenuFocus.link_vertical(_buttons)
	_resume_button.pressed.connect(_on_resume_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)


func focus_default() -> void:
	UiMenuFocus.grab_first(_buttons)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var vp := get_viewport()
	if vp == null:
		return
	UiMenuFocus.handle_confirm(event, vp)


func _on_resume_pressed() -> void:
	PauseManager.resume()


func _on_menu_pressed() -> void:
	PauseManager.return_to_main_menu()
