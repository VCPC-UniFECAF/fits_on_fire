extends Node2D

const StoryStateScript = preload("res://scripts/story_state.gd")

signal health_changed(current: int, maximum: int)
signal died

enum BossState { IDLE, WINDUP, ACTIVE, RECOVER }
enum AttackType { CLAW, TAIL, WING, FIRE }

@export var max_health: int = 500
@export var move_speed: float = 40.0
@export var reposition_distance: float = 180.0
@export var stop_distance: float = 100.0
@export var move_to_idle_delay: float = 0.5
@export var arena_margin: float = 80.0
@export var arena_bounds: Rect2 = Rect2(0, 0, 0, 0)
@export var claw_damage: int = 18
@export var tail_damage: int = 22
@export var wing_damage: int = 12
@export var fire_damage: int = 35

var health: int
var is_alive: bool = true
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
var _facing_right: bool = true
var _aim_direction: Vector2 = Vector2.RIGHT
var _arena_rect: Rect2 = Rect2()
var _has_arena_bounds: bool = false
var _is_moving: bool = false
var _was_moving: bool = false
var _move_to_idle_timer: float = 0.0

@onready var facing_pivot: Node2D = $FacingPivot
@onready var sprite: AnimatedSprite2D = $FacingPivot/AnimatedSprite2D
@onready var attack_sprite: AnimatedSprite2D = $FacingPivot/AnimatedSprite2D2
@onready var claw_hitbox: Area2D = $FacingPivot/ClawHitbox
@onready var tail_hitbox: Area2D = $FacingPivot/TailHitbox
@onready var wing_hitbox: Area2D = $FacingPivot/WingHitbox
@onready var fire_hitbox: Area2D = $FacingPivot/FireHitbox
@onready var hurtbox: Area2D = $FacingPivot/Hurtbox
@onready var _health_bar: EnemyHealthBar = $HUD/HealthBar

var _hit_players: Array = []
var _is_dead: bool = false


func _ready() -> void:
	add_to_group("boss")
	add_to_group("enemy")
	health = max_health
	health_changed.emit(health, max_health)
	if _health_bar:
		_health_bar.bind_host(self)
	_setup_arena_bounds()
	_disable_all_hitboxes()
	for hb in [claw_hitbox, tail_hitbox, wing_hitbox, fire_hitbox]:
		if hb:
			hb.body_entered.connect(_on_boss_hitbox.bind(hb))
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_set_attack_sprite_visible(false)
	_pick_next_attack()


func _setup_arena_bounds() -> void:
	var cam := get_parent().get_node_or_null("Camera2D") as Camera2D
	if cam:
		_arena_rect = Rect2(
			cam.limit_left + arena_margin,
			cam.limit_top + arena_margin,
			cam.limit_right - cam.limit_left - arena_margin * 2.0,
			cam.limit_bottom - cam.limit_top - arena_margin * 2.0
		)
		_has_arena_bounds = _arena_rect.size.x > 0.0 and _arena_rect.size.y > 0.0
	elif arena_bounds.size.x > 0.0 and arena_bounds.size.y > 0.0:
		_arena_rect = arena_bounds
		_has_arena_bounds = true


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_attack"):
		take_damage(area.damage)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	for key in _attack_cooldowns.keys():
		if _attack_cooldowns[key] > 0.0:
			_attack_cooldowns[key] -= delta

	var target := _get_nearest_player()
	if target and boss_state == BossState.IDLE:
		_update_aim(target)

	_is_moving = false
	if boss_state == BossState.IDLE and target:
		_try_reposition(delta, target)

	if _was_moving and not _is_moving:
		_move_to_idle_timer = move_to_idle_delay
	if _is_moving:
		_move_to_idle_timer = 0.0
	_was_moving = _is_moving

	if _move_to_idle_timer > 0.0:
		_move_to_idle_timer -= delta

	if boss_state == BossState.IDLE:
		_update_locomotion_anim(_is_moving)

	if _state_timer > 0.0:
		_state_timer -= delta
		if _state_timer <= 0.0:
			_advance_state()


func _try_reposition(delta: float, target: Node2D) -> void:
	var dist := global_position.distance_to(target.global_position)
	if dist <= reposition_distance:
		return

	var move_dir := global_position.direction_to(target.global_position)
	global_position += move_dir * move_speed * delta
	_clamp_to_arena()
	_is_moving = true


func _clamp_to_arena() -> void:
	if not _has_arena_bounds:
		return
	global_position = global_position.clamp(_arena_rect.position, _arena_rect.end)


func _update_aim(target: Node2D) -> void:
	if not target or not facing_pivot:
		return
	var dir := global_position.direction_to(target.global_position)
	if _current_attack == AttackType.TAIL and boss_state in [BossState.WINDUP, BossState.ACTIVE]:
		dir = -dir
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	var angle := dir.angle()
	if angle > PI / 2.0 or angle < -PI / 2.0:
		facing_pivot.scale.x = -1.0
		facing_pivot.scale.y = 1.0
		facing_pivot.rotation = PI - angle
	else:
		facing_pivot.scale.x = 1.0
		facing_pivot.scale.y = 1.0
		facing_pivot.rotation = angle
	_aim_direction = dir
	_facing_right = dir.x >= 0.0


func _update_locomotion_anim(is_moving: bool) -> void:
	if not sprite:
		return
	_set_attack_sprite_visible(false)
	if is_moving or _move_to_idle_timer > 0.0:
		if sprite.animation != "move":
			sprite.play("move")
	elif sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


func _advance_state() -> void:
	match boss_state:
		BossState.IDLE:
			var target := _get_nearest_player()
			if target == null:
				_state_timer = 1.0
				return
			if global_position.distance_to(target.global_position) > stop_distance:
				_state_timer = 0.3
				return
			boss_state = BossState.WINDUP
			_update_aim(target)
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
			_return_to_idle()
		BossState.RECOVER:
			boss_state = BossState.IDLE
			_state_timer = 0.5
			_pick_next_attack()


func _pick_next_attack() -> void:
	var target := _get_nearest_player()
	if target == null:
		_state_timer = 1.0
		return

	var dist: float = global_position.distance_to(target.global_position)
	if dist > stop_distance:
		_state_timer = 0.3
		return

	_current_attack = _choose_attack(dist)
	_update_aim(target)
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


func _get_nearest_player() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node2D and node.has_method("is_alive") and node.is_alive():
			var player := node as Node2D
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
			var dist: float = global_position.distance_to(player.global_position)
			if dist >= min_dist and dist < max_dist:
				count += 1
	return count


func take_damage(amount: int, _attacker: Node = null, _knockback_force: float = 0.0) -> void:
	if _is_dead:
		return
	health -= amount
	health_changed.emit(health, max_health)
	if health <= 0:
		_die()


func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	is_alive = false
	var story := get_node("/root/StoryState") as StoryStateScript
	if story:
		story.registrar_dragao_derrotado()
	died.emit()
	health_changed.emit(0, max_health)
	_disable_all_hitboxes()
	if sprite:
		sprite.visible = false
		sprite.stop()
	if attack_sprite and attack_sprite.sprite_frames.has_animation("death"):
		attack_sprite.visible = true
		attack_sprite.play("death")
		await attack_sprite.animation_finished
	else:
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
		var kb_dir := _aim_direction
		if kb_dir.length_squared() < 0.01:
			kb_dir = Vector2.RIGHT.rotated(facing_pivot.rotation)
		target.velocity += kb_dir * 60.0


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


func _set_attack_sprite_visible(show_attack: bool) -> void:
	if sprite:
		sprite.visible = not show_attack
	if attack_sprite:
		attack_sprite.visible = show_attack
		if not show_attack:
			attack_sprite.stop()


func _return_to_idle() -> void:
	_set_attack_sprite_visible(false)
	if sprite and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


func _play_windup_anim(attack: AttackType) -> void:
	match attack:
		AttackType.CLAW, AttackType.FIRE, AttackType.WING:
			_set_attack_sprite_visible(true)
			if not attack_sprite:
				return
			var attack_anim := ""
			match attack:
				AttackType.CLAW:
					attack_anim = "claw"
				AttackType.FIRE:
					attack_anim = "fire"
				AttackType.WING:
					attack_anim = "wing"
			if attack_anim != "" and attack_sprite.sprite_frames.has_animation(attack_anim):
				attack_sprite.play(attack_anim)
		AttackType.TAIL:
			_set_attack_sprite_visible(false)
			if sprite and sprite.sprite_frames.has_animation("tail"):
				sprite.play("tail")
			elif sprite and sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")
