class_name StoryProgress
extends Node
## Progresso narrativo global: fase máxima visitada e vitória sobre o Dragão Calórico.

var fase_narrativa_max: int = 1
var dragao_derrotado: bool = false
var cave_key_collected: bool = false
var cave_gate_unlocked: bool = false
var attack_power_multiplier: float = 1.0

var _power_up_scenes_collected: Dictionary = {}

const FASE_POR_CENA: Dictionary = {
	"house": 1,
	"woods": 2,
	"forest": 3,
	"ruins": 4,
	"cave": 5,
	"dragons_nest": 5,
}


func _ready() -> void:
	var tree := get_tree()
	if tree:
		tree.scene_changed.connect(_on_scene_changed)
		call_deferred("_registrar_cena_atual")


func _on_scene_changed() -> void:
	_registrar_cena_atual()


func _registrar_cena_atual() -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var path := tree.current_scene.scene_file_path
	if path.is_empty():
		return
	registrar_cena(path)


func registrar_cena(scene_path: String) -> void:
	var nome := scene_path.get_file().get_basename()
	if not FASE_POR_CENA.has(nome):
		return
	var fase: int = FASE_POR_CENA[nome]
	fase_narrativa_max = maxi(fase_narrativa_max, fase)


func registrar_dragao_derrotado() -> void:
	dragao_derrotado = true
	fase_narrativa_max = maxi(fase_narrativa_max, 5)


func collect_cave_key() -> void:
	cave_key_collected = true


func unlock_cave_gate() -> void:
	cave_gate_unlocked = true


func get_fase_efetiva() -> int:
	if dragao_derrotado:
		return 6
	return fase_narrativa_max


func get_attack_power_multiplier() -> float:
	return attack_power_multiplier


func is_power_up_collected(scene_path: String) -> bool:
	if scene_path.is_empty():
		return false
	var nome := scene_path.get_file().get_basename()
	return _power_up_scenes_collected.get(nome, false)


func collect_power_up(scene_path: String, factor: float = 1.25) -> bool:
	if scene_path.is_empty():
		return false
	var nome := scene_path.get_file().get_basename()
	if _power_up_scenes_collected.get(nome, false):
		return false
	_power_up_scenes_collected[nome] = true
	attack_power_multiplier *= factor
	return true


func reset_for_new_game() -> void:
	fase_narrativa_max = 1
	dragao_derrotado = false
	cave_key_collected = false
	cave_gate_unlocked = false
	attack_power_multiplier = 1.0
	_power_up_scenes_collected.clear()
