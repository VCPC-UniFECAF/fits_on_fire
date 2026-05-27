extends "res://scripts/enemy_base.gd"

enum OrcState { CHASE, ATTACK, COOLDOWN }

@export var orc_speed: float = 38.0
@export var attack_range: float = 28.0
@export var attack_damage: int = 20
@export var attack_duration: float = 0.35
@export var attack_cooldown_time: float = 1.0

var orc_state: OrcState = OrcState.CHASE
var _state_timer: float = 0.0
var _hit_players: Array = []

@onready var sword_hitbox: Area2D = $SwordHitbox


func _ready() -> void:
	speed = orc_speed
	engage_distance = 26.0
	flank_offset_x = 22.0
	super._ready()
	if sword_hitbox:
		sword_hitbox.monitoring = false
		sword_hitbox.body_entered.connect(_on_sword_hit_body)


func _process_enemy(delta: float) -> void:
	if _state_timer > 0.0:
		_state_timer -= delta

	match orc_state:
		OrcState.CHASE:
			_chase(delta)
			_update_locomotion_anim()
			var target := _get_nearest_player()
			if target and global_position.distance_to(target.global_position) <= attack_range:
				_start_attack(target)
		OrcState.ATTACK:
			_chase(delta)
			var attack_target := _get_nearest_player()
			if attack_target:
				_aim_sword_at(attack_target)
			if _state_timer <= 0.0:
				_end_attack()
		OrcState.COOLDOWN:
			_chase(delta)
			_update_locomotion_anim()
			if _state_timer <= 0.0:
				orc_state = OrcState.CHASE


func _chase(delta: float) -> void:
	move_chase(delta)


func _update_locomotion_anim() -> void:
	if not sprite or orc_state == OrcState.ATTACK:
		return
	if velocity.length() > 8.0:
		if sprite.sprite_frames.has_animation("walk") and sprite.animation != "walk":
			sprite.play("walk")
	else:
		if sprite.sprite_frames.has_animation("idle") and sprite.animation != "idle":
			sprite.play("idle")


func _aim_sword_at(target: Node2D) -> void:
	if not sword_hitbox or not target:
		return
	var dir := global_position.direction_to(target.global_position)
	sword_hitbox.rotation = dir.angle()


func _start_attack(target: Node2D) -> void:
	_hit_players.clear()
	orc_state = OrcState.ATTACK
	_state_timer = attack_duration
	_aim_sword_at(target)
	if sprite and sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")
	if sword_hitbox:
		sword_hitbox.monitoring = true
		get_tree().create_timer(attack_duration * 0.55).timeout.connect(
			func(): if sword_hitbox and orc_state == OrcState.ATTACK:
				sword_hitbox.monitoring = false
		)


func _end_attack() -> void:
	if sword_hitbox:
		sword_hitbox.monitoring = false
	_hit_players.clear()
	orc_state = OrcState.COOLDOWN
	_state_timer = attack_cooldown_time


func take_damage(amount: int, attacker: Node = null, knockback_force: float = 0.0) -> void:
	if is_alive and sprite and sprite.sprite_frames.has_animation("hit"):
		sprite.play("hit")
	super.take_damage(amount, attacker, knockback_force)


func _on_sword_hit_body(body: Node2D) -> void:
	if not body.is_in_group("player") or not body.has_method("take_damage"):
		return
	if body in _hit_players:
		return
	_hit_players.append(body)
	body.take_damage(attack_damage, self, knockback_distance)
