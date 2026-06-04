extends Node

enum Mode { SINGLE, MULTI }
enum Character { WARRIOR, WIZARD }

const HOUSE_SCENE := "res://scenes/house.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"

const LEVEL_SCENES: Array[String] = [
	"res://scenes/house.tscn",
	"res://scenes/woods.tscn",
	"res://scenes/forest.tscn",
	"res://scenes/ruins.tscn",
	"res://scenes/cave.tscn",
	"res://scenes/dragons_nest.tscn",
	"res://scenes/extralevel.tscn",
]

var mode: Mode = Mode.MULTI
var single_character: Character = Character.WARRIOR


func _ready() -> void:
	var tree := get_tree()
	if tree:
		tree.scene_changed.connect(_on_scene_changed)


func start_single_player(character: Character) -> void:
	mode = Mode.SINGLE
	single_character = character
	StoryState.reset_for_new_game()
	PlayerLives.reset_for_new_game()
	get_tree().change_scene_to_file(HOUSE_SCENE)


func start_multiplayer() -> void:
	mode = Mode.MULTI
	StoryState.reset_for_new_game()
	PlayerLives.reset_for_new_game()
	get_tree().change_scene_to_file(HOUSE_SCENE)


func return_to_menu() -> void:
	StoryState.reset_for_new_game()
	PlayerLives.reset_for_new_game()
	PortalTravel.clear_travel()
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_scene_changed() -> void:
	call_deferred("_apply_to_current_scene_deferred")


func _apply_to_current_scene_deferred() -> void:
	await get_tree().process_frame
	apply_to_current_scene()


func apply_to_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path.is_empty():
		return
	if not LEVEL_SCENES.has(scene.scene_file_path):
		return

	var warrior := scene.get_node_or_null("PlayerWarrior")
	var wizard := scene.get_node_or_null("PlayerWizard")
	if warrior == null or wizard == null:
		return

	match mode:
		Mode.SINGLE:
			if single_character == Character.WARRIOR:
				wizard.queue_free()
				warrior.player_id = 0
			else:
				warrior.queue_free()
				wizard.player_id = 0
			_configure_hud(scene, false)
		Mode.MULTI:
			warrior.player_id = 0
			wizard.player_id = 1
			_configure_hud(scene, true)

	_apply_player_lives(scene)


func _configure_hud(scene: Node, multiplayer_enabled: bool) -> void:
	var hud := scene.get_node_or_null("HUD")
	if hud and hud.has_method("set_multiplayer_hud"):
		hud.set_multiplayer_hud(multiplayer_enabled)
	if hud and hud.has_method("refresh_players"):
		hud.call_deferred("refresh_players")


func _apply_player_lives(scene: Node) -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node is PlayerBase:
			PlayerLives.apply_to_player(node as PlayerBase)

	var hud := scene.get_node_or_null("HUD")
	if hud and hud.has_method("refresh_lives_display"):
		hud.refresh_lives_display()
