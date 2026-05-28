extends Area2D

signal health_changed(current: int, maximum: int)

@export var max_health: int = 100
@export var speed: float = 30.0
@export var contact_damage: int = 15
@export var contact_cooldown: float = 1.0
@export var knockback_distance: float = 0.0
@export var engage_distance: float = 24.0
@export var flank_offset_x: float = 20.0

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

	var final_direction := (direction + push).normalized()
	velocity = velocity.lerp(final_direction * speed, 0.1)

	var slot := _get_flank_position(target)
	if dist_to_player <= engage_distance * 1.5 and global_position.distance_to(slot) < 2.0:
		velocity.x = lerpf(velocity.x, 0.0, 0.25)

	global_position += velocity * delta


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
		global_position += kb_dir * knockback_force * 0.05
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
