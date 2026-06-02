extends Area2D

const WALL_COLLISION_MASK := 1

signal health_changed(current: int, maximum: int)

@export var max_health: int = 100
@export var speed: float = 30.0
@export var contact_damage: int = 15
@export var contact_cooldown: float = 1.0
@export var knockback_distance: float = 0.0
@export var engage_distance: float = 24.0
@export var flank_offset_x: float = 20.0
@export var wall_probe_distance: float = 20.0
@export var wall_avoid_strength: float = 1.5

var health: int
var velocity: Vector2 = Vector2.ZERO
var is_alive: bool = true
var _contact_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _health_bar: EnemyHealthBar = $EnemyHealthBar


func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	health_changed.emit(health, max_health)
	if _health_bar:
		_health_bar.bind_host(self)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if _contact_timer > 0.0:
		_contact_timer -= delta
	_process_enemy(delta)
	_update_facing()


func _process_enemy(_delta: float) -> void:
	move_chase(_delta)


func _get_flank_position(target: Node2D) -> Vector2:
	var side := signf(global_position.x - target.global_position.x)
	if side == 0.0:
		side = 1.0
	return target.global_position + Vector2(side * flank_offset_x, 0.0)


func move_chase(delta: float) -> void:
	var target := _get_nearest_player()
	if target == null:
		return

	var dist_to_player := global_position.distance_to(target.global_position)
	var move_target := target.global_position
	if dist_to_player <= engage_distance * 1.5:
		move_target = _get_flank_position(target)

	var direction := global_position.direction_to(move_target)
	var push := Vector2.ZERO

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy != self and enemy is Node2D:
			if global_position.distance_to(enemy.global_position) < 20.0:
				push += enemy.global_position.direction_to(global_position)

	var wall_avoid := _get_wall_avoidance(direction)
	var combined := direction + push + wall_avoid
	var final_direction := combined.normalized() if combined.length_squared() > 0.0001 else direction
	velocity = velocity.lerp(final_direction * speed, 0.1)

	var slot := _get_flank_position(target)
	if dist_to_player <= engage_distance * 1.5 and global_position.distance_to(slot) < 2.0:
		velocity.x = lerpf(velocity.x, 0.0, 0.25)

	_apply_wall_aware_movement(velocity * delta, true)


func _get_collision_shape_params() -> PhysicsShapeQueryParameters2D:
	if not has_node("CollisionShape2D"):
		return null
	var col_shape: CollisionShape2D = $CollisionShape2D
	if col_shape.disabled or col_shape.shape == null:
		return null
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = col_shape.shape
	params.transform = col_shape.global_transform
	params.collision_mask = WALL_COLLISION_MASK
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = [get_rid()]
	return params


func _get_wall_avoidance(move_dir: Vector2) -> Vector2:
	if move_dir.length_squared() < 0.01:
		return Vector2.ZERO
	var space := get_world_2d().direct_space_state
	var avoid := Vector2.ZERO
	var probe_dir := move_dir.normalized()
	for angle_offset in [-PI * 0.25, 0.0, PI * 0.25]:
		var dir := probe_dir.rotated(angle_offset)
		var query := PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + dir * wall_probe_distance
		)
		query.collision_mask = WALL_COLLISION_MASK
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			avoid += hit.normal * wall_avoid_strength
	return avoid


func _get_wall_normal_at_motion(motion: Vector2) -> Vector2:
	if motion.is_zero_approx():
		return Vector2.ZERO
	var space := get_world_2d().direct_space_state
	var params := _get_collision_shape_params()
	if params != null:
		params.motion = motion
		var rest: Dictionary = space.get_rest_info(params)
		if not rest.is_empty() and rest.has("normal"):
			return rest["normal"]
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + motion.normalized() * wall_probe_distance
	)
	query.collision_mask = WALL_COLLISION_MASK
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		return hit.normal
	return Vector2.ZERO


func _apply_wall_aware_movement(motion: Vector2, update_velocity_on_hit: bool) -> void:
	if motion.is_zero_approx():
		return
	var params := _get_collision_shape_params()
	if params == null:
		global_position += motion
		return

	var space := get_world_2d().direct_space_state
	var col_shape: CollisionShape2D = $CollisionShape2D

	params.transform = col_shape.global_transform
	params.motion = motion
	var result := space.cast_motion(params)
	var safe_fraction: float = result[0]
	global_position += motion * safe_fraction

	if safe_fraction >= 1.0:
		return

	var wall_normal := _get_wall_normal_at_motion(motion)
	if wall_normal.is_zero_approx():
		return

	if update_velocity_on_hit:
		velocity = velocity.slide(wall_normal)

	var remainder := motion * (1.0 - safe_fraction)
	var slide_motion := remainder.slide(wall_normal)
	if slide_motion.is_zero_approx():
		return

	params.transform = col_shape.global_transform
	params.motion = slide_motion
	result = space.cast_motion(params)
	safe_fraction = result[0]
	global_position += slide_motion * safe_fraction

	if safe_fraction < 1.0 and update_velocity_on_hit:
		var wall_normal2 := _get_wall_normal_at_motion(slide_motion)
		if not wall_normal2.is_zero_approx():
			velocity = velocity.slide(wall_normal2)


func _get_nearest_player() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node2D and node.has_method("is_alive") and node.is_alive():
			var dist := global_position.distance_squared_to(node.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = node
	return nearest


func _update_facing() -> void:
	if not sprite:
		return
	var target := _get_nearest_player()
	if target == null:
		return
	sprite.flip_h = global_position.x > target.global_position.x


func take_damage(amount: int, _attacker: Node = null, knockback_force: float = 0.0) -> void:
	if not is_alive:
		return
	health -= amount
	health_changed.emit(health, max_health)
	if knockback_force > 0.0 and _attacker is Node2D:
		var kb_dir := global_position.direction_to(_attacker.global_position) * -1.0
		_apply_wall_aware_movement(kb_dir * knockback_force * 0.05, false)
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("hit")
	if health <= 0:
		die()


func die() -> void:
	if not is_alive:
		return
	is_alive = false
	health_changed.emit(0, max_health)
	if _health_bar:
		_health_bar.visible = false
	if sprite and sprite.sprite_frames.has_animation("die"):
		sprite.play("die")
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	if has_node("BodyCollision/CollisionShape2D"):
		$BodyCollision/CollisionShape2D.set_deferred("disabled", true)
	await get_tree().create_timer(1.0).timeout
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not is_alive:
		return
	if area.is_in_group("player_attack"):
		take_damage(area.damage)
		return
	_try_damage_player(area.get_parent())


func _on_body_entered(body: Node2D) -> void:
	if not is_alive:
		return
	_try_damage_player(body)


func _try_damage_player(target: Node) -> void:
	if target == null or not target.is_in_group("player"):
		return
	if not target.has_method("take_damage"):
		return
	if _contact_timer <= 0.0:
		target.take_damage(contact_damage, self, knockback_distance)
		_contact_timer = contact_cooldown
