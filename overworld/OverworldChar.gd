class_name OverworldChar extends CharacterBody2D

@onready var ray : RayCast2D = $RayCast2D
var _movement := []
var speed := 3.0

func move(pos : Vector2):
	_movement.append(pos * speed)
func _process_move():
	for i in _movement:
		ray.target_position = i
		if(!ray.collide_with_areas):
			position += i
		else:
			continue

func _physics_process(_delta: float) -> void:
	_process_move()
