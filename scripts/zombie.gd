extends "res://scripts/enemy_base.gd"

@export var zombie_speed: float = 28.0


func _ready() -> void:
	speed = zombie_speed
	engage_distance = 20.0
	flank_offset_x = 16.0
	super._ready()
