extends CharacterBody2D
class_name PlayerBase

enum State { IDLE, MOVE, ATTACK_LIGHT, ATTACK_HEAVY, HIT, DEAD }

signal health_changed(current: int, maximum: int)

@export var player_id: int = 0
@export var max_health: int = 100
@export var speed: float = 60.0
@export var heavy_cooldown: float = 1.5

var health: int
var direction: Vector2 = Vector2.ZERO
var state: State = State.IDLE
var facing_right: bool = true
var can_be_hit: bool = true
var heavy_cooldown_timer: float = 0.0
var attack_timer: float = 0.0
var _knockback_timer: float = 0.0
var attack_multiplier: float = 1.0

const KNOCKBACK_SLIDE_DURATION: float = 0.2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("player")
	health = max_health
	health_changed.emit(health, max_health)
	if sprite:
		sprite.animation_finished.connect(_on_animation_finished)
	call_deferred("_register_player_collision_exceptions")
	_sync_attack_multiplier_from_story()


func _register_player_collision_exceptions() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D and node != self:
			add_collision_exception_with(node)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if heavy_cooldown_timer > 0.0:
		heavy_cooldown_timer -= delta

	if attack_timer > 0.0:
		attack_timer -= delta
		if attack_timer <= 0.0 and state in [State.ATTACK_LIGHT, State.ATTACK_HEAVY]:
			_end_attack()

	match state:
		State.IDLE, State.MOVE:
			_apply_movement_from_input()
			_update_locomotion_state()
			_process_attack_input()
		State.ATTACK_LIGHT, State.ATTACK_HEAVY:
			_apply_movement_from_input()
		State.HIT:
			if _knockback_timer > 0.0:
				_knockback_timer -= delta
			else:
				velocity = velocity.move_toward(Vector2.ZERO, speed * 3.0 * delta)

	_apply_partner_velocity_limit()
	move_and_slide()
	_apply_partner_position_clamp()
	_update_animation()


func get_input_prefix() -> String:
	return "p%d_" % (player_id + 1)


func get_move_vector() -> Vector2:
	var prefix := get_input_prefix()
	return Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")


func _apply_movement_from_input() -> void:
	direction = get_move_vector()
	if direction != Vector2.ZERO:
		velocity = direction * speed
		if abs(direction.x) > 0.01:
			facing_right = direction.x > 0.0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)


func _update_locomotion_state() -> void:
	if direction != Vector2.ZERO:
		state = State.MOVE
	else:
		state = State.IDLE


func _process_attack_input() -> void:
	if Input.is_action_just_pressed(get_input_prefix() + "light"):
		_start_light_attack()
	elif Input.is_action_just_pressed(get_input_prefix() + "heavy") and heavy_cooldown_timer <= 0.0:
		_start_heavy_attack()


func _start_light_attack() -> void:
	state = State.ATTACK_LIGHT
	attack_timer = _get_light_attack_duration()
	_perform_light_attack()
	if sprite and sprite.sprite_frames.has_animation("attack_light"):
		sprite.play("attack_light")


func _start_heavy_attack() -> void:
	state = State.ATTACK_HEAVY
	attack_timer = _get_heavy_attack_duration()
	heavy_cooldown_timer = heavy_cooldown
	_perform_heavy_attack()
	if sprite and sprite.sprite_frames.has_animation("attack_heavy"):
		sprite.play("attack_heavy")

func _sync_attack_multiplier_from_story() -> void:
	var story := get_node_or_null("/root/StoryState") as StoryProgress
	if story:
		attack_multiplier = story.get_attack_power_multiplier()


func apply_attack_power_up(multiplier: float = 1.25) -> void:
	var story := get_node_or_null("/root/StoryState") as StoryProgress
	if story == null:
		attack_multiplier *= multiplier
		return
	var path := ""
	if get_tree().current_scene:
		path = get_tree().current_scene.scene_file_path
	if story.collect_power_up(path, multiplier):
		attack_multiplier = story.get_attack_power_multiplier()


func get_scaled_damage(base_damage: int) -> int:
	return maxi(1, roundi(base_damage * attack_multiplier))



func _end_attack() -> void:
	state = State.IDLE if direction == Vector2.ZERO else State.MOVE


func take_damage(amount: int, attacker: Node = null, knockback_distance: float = 0.0) -> void:
	if not can_be_hit or state == State.DEAD:
		return

	health -= amount
	health_changed.emit(health, max_health)
	if health <= 0:
		die()
		return

	if knockback_distance > 0.0 and attacker is Node2D:
		var kb_dir: Vector2 = global_position - (attacker as Node2D).global_position
		if kb_dir.length_squared() < 0.01:
			kb_dir = Vector2.RIGHT if facing_right else Vector2.LEFT
		else:
			kb_dir = kb_dir.normalized()
		var knockback_speed := knockback_distance / KNOCKBACK_SLIDE_DURATION
		velocity = kb_dir * knockback_speed
		_knockback_timer = KNOCKBACK_SLIDE_DURATION

	state = State.HIT
	can_be_hit = false
	if sprite and sprite.sprite_frames.has_animation("hit"):
		sprite.play("hit")
	_get_hit_recovery()
	pass

func heal(amount: int) -> void:
	if state == State.DEAD:
		return

	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)
pass

func heal_to_full() -> void:
	if state == State.DEAD:
		return
	
	if health >= max_health:
		return
	
	health = max_health
	health_changed.emit(health, max_health)
	
pass

func _get_hit_recovery() -> void:
	await get_tree().create_timer(0.5).timeout
	can_be_hit = true
	_knockback_timer = 0.0
	if state == State.HIT:
		state = State.IDLE


func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	velocity = Vector2.ZERO
	if sprite and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)


func is_alive() -> bool:
	return state != State.DEAD and health > 0


func _on_animation_finished() -> void:
	if state in [State.ATTACK_LIGHT, State.ATTACK_HEAVY]:
		_end_attack()


func _update_animation() -> void:
	if not sprite:
		return
	if state in [State.ATTACK_LIGHT, State.ATTACK_HEAVY, State.HIT, State.DEAD]:
		if state != State.DEAD:
			sprite.flip_h = not facing_right
		return

	sprite.flip_h = not facing_right

	if direction == Vector2.ZERO:
		if sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
	else:
		if abs(direction.x) > abs(direction.y):
			if sprite.sprite_frames.has_animation("walk_side"):
				sprite.play("walk_side")
		else:
			if direction.y < 0:
				if sprite.sprite_frames.has_animation("walk_up"):
					sprite.play("walk_up")
				elif sprite.sprite_frames.has_animation("up"):
					sprite.play("up")
				elif sprite.sprite_frames.has_animation("walk_side"):
					sprite.play("walk_side")
			elif direction.y > 0:
				if sprite.sprite_frames.has_animation("walk_down"):
					sprite.play("walk_down")
				elif sprite.sprite_frames.has_animation("down"):
					sprite.play("down")
				elif sprite.sprite_frames.has_animation("walk_side"):
					sprite.play("walk_side")
			elif sprite.sprite_frames.has_animation("walk_side"):
				sprite.play("walk_side")


func _get_light_attack_duration() -> float:
	return 0.25


func _get_heavy_attack_duration() -> float:
	return 0.45


func _perform_light_attack() -> void:
	pass


func _perform_heavy_attack() -> void:
	pass


func _get_max_player_distance() -> float:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("get_max_player_distance"):
		return cam.get_max_player_distance()
	return 9999.0


func _get_other_alive_player() -> PlayerBase:
	for node in get_tree().get_nodes_in_group("player"):
		if node is PlayerBase and node != self and node.is_alive():
			return node
	return null


func _apply_partner_velocity_limit() -> void:
	var other := _get_other_alive_player()
	if not other or not is_alive():
		return

	var max_dist := _get_max_player_distance()
	var offset := global_position - other.global_position
	var dist := offset.length()
	if dist < 0.001:
		return

	var away_dir := offset / dist
	if dist >= max_dist - 1.0 and velocity.dot(away_dir) > 0.0:
		velocity = velocity.slide(away_dir)


func _apply_partner_position_clamp() -> void:
	var other := _get_other_alive_player()
	if not other or not is_alive():
		return

	var max_dist := _get_max_player_distance()
	var offset := global_position - other.global_position
	var dist := offset.length()
	if dist > max_dist and dist > 0.001:
		global_position = other.global_position + offset / dist * max_dist
