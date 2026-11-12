class_name TargetedPellet extends BattleBullet

# All positions are relative to the bullet container; all times are seconds.
var rest_position := Vector2.ZERO
var approach_duration := 0.35
var hold_duration := 0.5
var launch_velocity := Vector2.ZERO
var radius := 6.0:
	set(value):
		radius = maxf(value, 0.01)
		if is_instance_valid(_shape): _shape.radius = radius
		queue_redraw()
var age := 0.0
var _start_position := Vector2.ZERO
var _motion := Vector2.ZERO
var _shape: CircleShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	_start_position = position
	if approach_duration <= 0.0:
		_start_position = rest_position
		position = rest_position
	_shape = CircleShape2D.new()
	_shape.radius = radius
	var collision := CollisionShape2D.new()
	collision.shape = _shape
	add_child(collision)
	super._ready()


func _physics_process(delta: float) -> void:
	var remaining := minf(delta, maxf(lifetime, 0.0))
	if remaining <= 0.0:
		queue_free()
		return
	var approach_end := maxf(approach_duration, 0.0)
	var launch_at := approach_end + maxf(hold_duration, 0.0)
	# Split an update at phase boundaries so a long frame follows the actual
	# path instead of sweeping diagonally across a change of direction.
	while remaining > 0.00000001 and not is_queued_for_deletion():
		var step := remaining
		if age < approach_end: step = minf(step, approach_end - age)
		elif age < launch_at: step = minf(step, launch_at - age)
		_motion = _position_at(age + step) - _position_at(age)
		age += step
		super._physics_process(step)
		remaining -= step
	queue_redraw()


func _motion_for_step(_step: float) -> Vector2:
	return _motion


func _position_at(time: float) -> Vector2:
	var duration := maxf(approach_duration, 0.0)
	var progress := clampf(time / duration, 0.0, 1.0) if duration > 0.0 else 1.0
	# Smooth arrival, independent of update rate.
	progress = progress * progress * (3.0 - 2.0 * progress)
	var launched_for := maxf(0.0, time - duration - maxf(hold_duration, 0.0))
	return _start_position.lerp(rest_position, progress) + launch_velocity * launched_for


func _draw() -> void:
	var colors := [Color.WHITE, Color.CYAN, Color.ORANGE, Color.LIME_GREEN]
	draw_circle(Vector2.ZERO, radius, colors[rule])
