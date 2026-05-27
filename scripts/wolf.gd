extends "res://scripts/enemy_base.gd"

enum WolfState { CHASE, ATTACK, COOLDOWN }

@export var wolf_speed: float = 38.0
@export var attack_range: float = 28.0
@export var attack_damage: int = 20
@export var attack_duration: float = 0.35
@export var attack_cooldown_time: float = 1.0

var wolf_state: WolfState = WolfState.CHASE
var _state_timer: float = 0.0
var _hit_players: Array = []

@onready var sword_hitbox: Area2D = $SwordHitbox


func _ready() -> void:
	speed = wolf_speed
	engage_distance = 26.0
	flank_offset_x = 22.0
	super._ready()
	if sword_hitbox:
		sword_hitbox.monitoring = false
		sword_hitbox.body_entered.connect(_on_sword_hit_body)


func _process_enemy(delta: float) -> void:
	if _state_timer > 0.0:
		_state_timer -= delta

	match wolf_state:
		WolfState.CHASE:
			_chase(delta)
			var target := _get_nearest_player()
			if target and global_position.distance_to(target.global_position) <= attack_range:
				_start_attack(target)
		WolfState.ATTACK:
			_chase(delta)
			var attack_target := _get_nearest_player()
			if attack_target:
				_aim_sword_at(attack_target)
			if _state_timer <= 0.0:
				_end_attack()
		WolfState.COOLDOWN:
			_chase(delta)
			if _state_timer <= 0.0:
				wolf_state = WolfState.CHASE


func _chase(delta: float) -> void:
	move_chase(delta)


func _aim_sword_at(target: Node2D) -> void:
	if not sword_hitbox or not target:
		return
	var dir := global_position.direction_to(target.global_position)
	sword_hitbox.rotation = dir.angle()


func _start_attack(target: Node2D) -> void:
	_hit_players.clear()
	wolf_state = WolfState.ATTACK
	_state_timer = attack_duration
	_aim_sword_at(target)
	if sprite and sprite.sprite_frames.has_animation("slash"):
		sprite.play("slash")
	elif sprite and sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")
	if sword_hitbox:
		sword_hitbox.monitoring = true
		get_tree().create_timer(attack_duration * 0.55).timeout.connect(
			func(): if sword_hitbox and wolf_state == WolfState.ATTACK:
				sword_hitbox.monitoring = false
		)


func _end_attack() -> void:
	if sword_hitbox:
		sword_hitbox.monitoring = false
	_hit_players.clear()
	wolf_state = WolfState.COOLDOWN
	_state_timer = attack_cooldown_time


func _on_sword_hit_body(body: Node2D) -> void:
	if not body.is_in_group("player") or not body.has_method("take_damage"):
		return
	if body in _hit_players:
		return
	_hit_players.append(body)
	body.take_damage(attack_damage, self, knockback_distance)
