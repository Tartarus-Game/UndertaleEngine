class_name OverworldChar extends CharacterBody2D

@export var speed: float = 180.0 # pixels per second
@export var movement_enabled := true
var movement_direction := Vector2.ZERO


func move(direction: Vector2) -> void:
	movement_direction = direction.limit_length()


func _physics_process(_delta: float) -> void:
	velocity = movement_direction * speed if movement_enabled else Vector2.ZERO
	move_and_slide() # Godot applies the physics timestep internally.
