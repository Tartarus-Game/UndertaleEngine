class_name Shaker extends Node

var target: Node
var target_property: String
var shake_distance: float
var shake_speed: int
var shake_decrease: float
var shake_random: bool

var _shake_base: float
var _shake_pos: float = 0.0
var _shake_time: int = 0
var _shake_positive: bool = true

func _init(t_node: Node, prop: String, dist: float, speed: int = 0, decrease: float = 1.0, is_random: bool = false):
	target = t_node
	target_property = prop
	shake_distance = dist
	shake_speed = speed
	shake_decrease = decrease
	shake_random = is_random
	#_shake_base = target.get(target_property)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target) or shake_distance <= 0:
		if is_instance_valid(target):
			target.set(target_property, _shake_base)
		queue_free()
		return
		
	if _shake_time > 0:
		_shake_time -= 1
	else:
		if not shake_random:
			if _shake_positive:
				_shake_pos = shake_distance
			else:
				shake_distance -= shake_decrease
				_shake_pos = -shake_distance
			_shake_positive = not _shake_positive
		else:
			_shake_pos = randf_range(-shake_distance, shake_distance)
			shake_distance -= shake_decrease
			
		_shake_time = shake_speed
		
	target.set(target_property, _shake_base + _shake_pos)
