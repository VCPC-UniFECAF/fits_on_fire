extends PlayerBase

@export var light_damage: int = 8
@export var heavy_damage: int = 40
@export var light_projectile_count: int = 1
@export var light_projectile_interval: float = 0.08
@export var light_projectile_speed: float = 140.0
@export var heavy_projectile_speed: float = 70.0
@export var heavy_cooldown_override: float = 2.5

const PROJECTILE_SCENE := preload("res://prefabs/projectile.tscn")

@onready var wand: Wand = $wand


func _ready() -> void:
	super._ready()
	heavy_cooldown = heavy_cooldown_override


func _uses_mouse_attacks() -> bool:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return false
	return (
		session.mode == session.Mode.SINGLE
		and session.single_character == session.Character.WIZARD
	)


func _process_attack_input() -> void:
	if _uses_mouse_attacks():
		if Input.is_action_just_pressed("p2_light"):
			_start_light_attack()
		elif Input.is_action_just_pressed("p2_heavy") and heavy_cooldown_timer <= 0.0:
			_start_heavy_attack()
		return
	super._process_attack_input()


func _get_light_attack_duration() -> float:
	return light_projectile_interval * light_projectile_count + 0.1


func _get_heavy_attack_duration() -> float:
	return 0.5


func _perform_light_attack() -> void:
	_spawn_light_burst()


func _perform_heavy_attack() -> void:
	_spawn_projectile(
		get_scaled_damage(heavy_damage),
		heavy_projectile_speed, 2.0, 14.0, 5
	)


func _spawn_light_burst() -> void:
	for i in light_projectile_count:
		get_tree().create_timer(light_projectile_interval * i).timeout.connect(
			_spawn_projectile.bind(
				get_scaled_damage(light_damage),
				light_projectile_speed, 0.8, 10.0, 1
			)
		)


func _spawn_projectile(dmg: int, spd: float, life: float, spawn_offset: float, size_scale: float) -> void:
	if not wand:
		return

	var proj := PROJECTILE_SCENE.instantiate()
	get_parent().add_child(proj)
	var dir: Vector2 = wand.aim_direction
	var spawn_pos: Vector2 = wand.get_muzzle_position(spawn_offset)
	proj.global_position = spawn_pos
	proj.setup(self, dir, dmg, spd, life)
	if proj.has_node("CollisionShape2D"):
		var shape := proj.get_node("CollisionShape2D")
		if shape.shape is CircleShape2D:
			shape.shape.radius = size_scale * 0.5
	if proj.has_node("Sprite2D"):
		proj.get_node("Sprite2D").scale = Vector2(size_scale, size_scale)
