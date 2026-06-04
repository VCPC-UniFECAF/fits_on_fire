extends CanvasLayer

@onready var _resume_button: Button = $Control/CenterContainer/VBoxContainer/ResumeButton
@onready var _menu_button: Button = $Control/CenterContainer/VBoxContainer/MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_resume_button.pressed.connect(_on_resume_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)


func _on_resume_pressed() -> void:
	PauseManager.resume()


func _on_menu_pressed() -> void:
	PauseManager.return_to_main_menu()
