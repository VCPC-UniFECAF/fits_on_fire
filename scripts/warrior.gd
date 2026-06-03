extends PlayerBase

@export var light_damage: int = 15
@export var heavy_damage: int = 35
@export var light_hitbox_offset: Vector2 = Vector2(18, 0)
@export var heavy_hitbox_offset: Vector2 = Vector2(22, 0)
@export var attack_knockback: float = 30.0

const HITBOX_SCENE := preload("res://prefabs/hitbox.tscn")


func _get_light_attack_duration() -> float:
	return 0.3


func _get_heavy_attack_duration() -> float:
	return 0.5


func _perform_light_attack() -> void:
	_spawn_hitbox(get_scaled_damage(light_damage), light_hitbox_offset, 0.2, attack_knockback)


func _perform_heavy_attack() -> void:
	_spawn_hitbox(get_scaled_damage(heavy_damage), heavy_hitbox_offset, 0.35, attack_knockback)


func _spawn_hitbox(dmg: int, offset: Vector2, life: float, kb: float) -> void:
	var hb := HITBOX_SCENE.instantiate()
	get_parent().add_child(hb)
	var dir := Vector2.RIGHT if facing_right else Vector2.LEFT
	hb.rotation = dir.angle()
	hb.global_position = global_position + offset.rotated(hb.rotation)
	hb.setup(self, dmg, life, kb)
