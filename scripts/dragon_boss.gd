extends Node2D

enum BossState { IDLE, WINDUP, ACTIVE, RECOVER }
enum AttackType { CLAW, TAIL, WING, FIRE }

@export var max_health: int = 500
@export var anchor_x: float = 40.0
@export var claw_damage: int = 18
@export var tail_damage: int = 22
@export var wing_damage: int = 12
@export var fire_damage: int = 35

var health: int
var boss_state: BossState = BossState.IDLE
var _state_timer: float = 0.0
var _attack_cooldowns: Dictionary = {
	"claw": 0.0,
	"tail": 0.0,
	"wing": 0.0,
	"fire": 0.0,
}
var _consecutive_claws: int = 0
var _current_attack: AttackType = AttackType.CLAW

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var claw_hitbox: Area2D = $ClawHitbox
@onready var tail_hitbox: Area2D = $TailHitbox
@onready var wing_hitbox: Area2D = $WingHitbox
@onready var fire_hitbox: Area2D = $FireHitbox
@onready var hurtbox: Area2D = $Hurtbox

var _hit_players: Array = []


func _ready() -> void:
	add_to_group("boss")
	add_to_group("enemy")
	health = max_health
	global_position.x = anchor_x
	_disable_all_hitboxes()
	for hb in [claw_hitbox, tail_hitbox, wing_hitbox, fire_hitbox]:
		if hb:
			hb.body_entered.connect(_on_boss_hitbox.bind(hb))
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_pick_next_attack()


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_attack"):
		take_damage(area.damage)


func _physics_process(delta: float) -> void:
	global_position.x = anchor_x
	for key in _attack_cooldowns.keys():
		if _attack_cooldowns[key] > 0.0:
			_attack_cooldowns[key] -= delta

	if _state_timer > 0.0:
		_state_timer -= delta
		if _state_timer <= 0.0:
			_advance_state()
			return


func _advance_state() -> void:
	match boss_state:
		BossState.IDLE:
			boss_state = BossState.WINDUP
			_state_timer = _get_windup_time(_current_attack)
			_play_windup_anim(_current_attack)
		BossState.WINDUP:
			boss_state = BossState.ACTIVE
			_state_timer = _get_active_time(_current_attack)
			_enable_attack_hitbox(_current_attack)
		BossState.ACTIVE:
			_disable_all_hitboxes()
			boss_state = BossState.RECOVER
			_state_timer = _get_recover_time(_current_attack)
		BossState.RECOVER:
			boss_state = BossState.IDLE
			_state_timer = 0.5
			_pick_next_attack()


func _pick_next_attack() -> void:
	var target := _nearest_player_to_right()
	if target == null:
		_state_timer = 1.0
		return

	var dist: float = target.global_position.x - global_position.x
	_current_attack = _choose_attack(dist)
	boss_state = BossState.IDLE
	_state_timer = 0.3


func _choose_attack(dist: float) -> AttackType:
	if health < max_health * 0.5 and dist > 100.0 and _attack_cooldowns["fire"] <= 0.0:
		return AttackType.FIRE
	if dist > 140.0 and _attack_cooldowns["fire"] <= 0.0:
		return AttackType.FIRE
	if dist < 90.0:
		_consecutive_claws += 1
		return AttackType.CLAW
	if _players_in_range(90.0, 150.0) >= 2 or _consecutive_claws >= 2:
		_consecutive_claws = 0
		if _attack_cooldowns["wing"] <= 0.0:
			return AttackType.WING
	if randf() < 0.25 and _attack_cooldowns["tail"] <= 0.0:
		return AttackType.TAIL
	if _attack_cooldowns["claw"] <= 0.0:
		return AttackType.CLAW
	return AttackType.TAIL


func _nearest_player_to_right() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node2D and node.has_method("is_alive") and node.is_alive():
			var player := node as Node2D
			if player.global_position.x < global_position.x:
				continue
			var dist: float = global_position.distance_squared_to(player.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = player
	return nearest


func _players_in_range(min_dist: float, max_dist: float) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node2D and node.has_method("is_alive") and node.is_alive():
			var player := node as Node2D
			if player.global_position.x <= global_position.x:
				continue
			var dist_x: float = player.global_position.x - global_position.x
			if dist_x >= min_dist and dist_x < max_dist:
				count += 1
	return count


func take_damage(amount: int, _attacker: Node = null, _knockback_force: float = 0.0) -> void:
	health -= amount
	if health <= 0:
		_die()


func _die() -> void:
	_disable_all_hitboxes()
	if sprite and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	await get_tree().create_timer(2.0).timeout
	queue_free()


func _disable_all_hitboxes() -> void:
	for hb in [claw_hitbox, tail_hitbox, wing_hitbox, fire_hitbox]:
		if hb:
			hb.monitoring = false
	_hit_players.clear()


func _enable_attack_hitbox(attack: AttackType) -> void:
	_disable_all_hitboxes()
	_hit_players.clear()
	match attack:
		AttackType.CLAW:
			if claw_hitbox:
				claw_hitbox.monitoring = true
			_attack_cooldowns["claw"] = 1.2
		AttackType.TAIL:
			if tail_hitbox:
				tail_hitbox.monitoring = true
			_attack_cooldowns["tail"] = 2.5
		AttackType.WING:
			if wing_hitbox:
				wing_hitbox.monitoring = true
			_attack_cooldowns["wing"] = 3.0
		AttackType.FIRE:
			if fire_hitbox:
				fire_hitbox.monitoring = true
			_attack_cooldowns["fire"] = 5.0


func _get_damage_for_attack(attack: AttackType) -> int:
	match attack:
		AttackType.CLAW:
			return claw_damage
		AttackType.TAIL:
			return tail_damage
		AttackType.WING:
			return wing_damage
		AttackType.FIRE:
			return fire_damage
	return 10


func _on_boss_hitbox(body_or_area: Node2D, _hitbox: Area2D) -> void:
	var target: Node2D = body_or_area
	if body_or_area is Area2D:
		target = body_or_area.get_parent() as Node2D
	if target == null or not target.is_in_group("player"):
		return
	if target in _hit_players:
		return
	if not target.has_method("take_damage"):
		return
	_hit_players.append(target)
	target.take_damage(_get_damage_for_attack(_current_attack))
	if _current_attack == AttackType.WING and target is CharacterBody2D:
		target.velocity += Vector2(60.0, 0.0)


func _get_windup_time(attack: AttackType) -> float:
	match attack:
		AttackType.FIRE:
			return 1.2
		AttackType.TAIL:
			return 0.6
		_:
			return 0.4


func _get_active_time(attack: AttackType) -> float:
	match attack:
		AttackType.FIRE:
			return 1.0
		AttackType.WING:
			return 0.5
		_:
			return 0.35


func _get_recover_time(_attack: AttackType) -> float:
	return 0.8


func _play_windup_anim(attack: AttackType) -> void:
	if not sprite:
		return
	var anim_name := ""
	match attack:
		AttackType.CLAW:
			anim_name = "claw"
		AttackType.TAIL:
			anim_name = "tail"
		AttackType.WING:
			anim_name = "wing"
		AttackType.FIRE:
			anim_name = "fire"
	if anim_name != "" and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	elif sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
