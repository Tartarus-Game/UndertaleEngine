class_name BoneRing extends Node2D

var angular_velocity := 1.0 # radians per second
var lifetime := 6.0


func _physics_process(delta: float) -> void:
	rotation += angular_velocity * delta
	lifetime -= delta
	if lifetime <= 0.0: queue_free()
