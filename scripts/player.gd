extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D

var speed = 60
var direction = Vector2.ZERO


func _ready() -> void:
	add_to_group("player")
	pass


func _physics_process(_delta: float) -> void:
	move()
	#anim()
	
	pass


func move ():
	
	direction = Input.get_vector("left", "right", "up", "down")
	
	if direction != Vector2.ZERO:
		velocity = direction * speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
	
	if Input.is_action_just_pressed("hit"):
		print("ta clicando porra")
	
	move_and_slide()
	pass




func anim():
	
	if direction == Vector2.ZERO:
		sprite.play("idle")
	
	else:
		if abs(direction.x) > abs(direction.y):
			sprite.play("walk_side")
			if direction.x < 0:
				sprite.flip_h = true
			else:
				sprite.flip_h = false
		else:
			if abs(direction.y) > abs(direction.x):
				if direction.y < 0:
					sprite.play("up")
				else:
					sprite.play("down")
	
	
	
	pass
