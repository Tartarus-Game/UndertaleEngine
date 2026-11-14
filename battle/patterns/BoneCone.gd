class_name BoneCone extends BattleBullet

# Angle and angular speed are in radians and radians per second.
var target_angle := 0.0
var turn_speed := PI
var charge_duration := 0.5
var speed := 0.0
var acceleration := 240.0
var length := 40.0
var width := 12.0
var age := 0.0
var _motion := Vector2.ZERO


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	destroy_on_contact = false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length, width)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	super._ready()


func _physics_process(delta: float) -> void:
	var remaining := minf(delta, maxf(lifetime, 0.0))
	if remaining <= 0.0:
		queue_free()
		return
	var elapsed := 0.0
	while remaining > 0.00000001 and not is_queued_for_deletion():
		var difference := angle_difference(rotation, target_angle)
		var angular_speed := signf(difference) * maxf(turn_speed, 0.0) if absf(difference) > 0.000001 else 0.0
		var step := remaining
		if age < charge_duration:
			step = minf(step, charge_duration - age)
		if absf(angular_speed) > 0.000001:
			step = minf(step, absf(difference / angular_speed))
		var start_angle := rotation
		var moving := age >= charge_duration
		_motion = _integrate_motion(start_angle, angular_speed, step) if moving else Vector2.ZERO
		if moving: speed += acceleration * step
		rotation = rotate_toward(start_angle, target_angle, absf(angular_speed) * step)
		age += step
		_advance_physics(step, elapsed / delta, (elapsed + step) / delta)
		elapsed += step
		remaining -= step
	queue_redraw()


func _integrate_motion(start_angle: float, angular_speed: float, delta: float) -> Vector2:
	if absf(angular_speed) < 0.0001:
		return Vector2.RIGHT.rotated(start_angle) * (speed * delta + 0.5 * acceleration * delta * delta)
	var end_angle := start_angle + angular_speed * delta
	var w := angular_speed
	var x := speed * (sin(end_angle) - sin(start_angle)) / w
	x += acceleration * (delta * sin(end_angle) / w + (cos(end_angle) - cos(start_angle)) / (w * w))
	var y := speed * (cos(start_angle) - cos(end_angle)) / w
	y += acceleration * (-delta * cos(end_angle) / w + (sin(end_angle) - sin(start_angle)) / (w * w))
	return Vector2(x, y)


func _motion_for_step(_step: float) -> Vector2:
	return _motion


func _draw() -> void:
	var colors := [Color.WHITE, Color.CYAN, Color.ORANGE, Color.LIME_GREEN]
	var color: Color = colors[rule]
	if age < charge_duration: color.a = 0.65
	draw_colored_polygon(PackedVector2Array([
		Vector2(-length / 2.0, -width / 2.0),
		Vector2(length / 2.0, 0.0),
		Vector2(-length / 2.0, width / 2.0)
	]), color)
