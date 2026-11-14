class_name TargetedPellet extends BattleBullet

enum LaunchTiming { AFTER_APPROACH, FROM_SPAWN }
enum ApproachEase { SMOOTH, LINEAR, BACK_OUT }

# All positions are relative to the bullet container; all times are seconds.
var rest_position := Vector2.ZERO
var approach_duration := 0.35
var hold_duration := 0.5
var launch_velocity := Vector2.ZERO
var launch_timing := LaunchTiming.AFTER_APPROACH
var approach_ease := ApproachEase.SMOOTH
var recoil_distance := 0.0
var recoil_duration := 0.0
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
	var launch_at := _launch_time()
	var recoil_end := launch_at + maxf(recoil_duration, 0.0) if recoil_distance > 0.0 else launch_at
	var boundaries := [approach_end, launch_at, recoil_end]
	if approach_ease == ApproachEase.BACK_OUT:
		# Back-out reverses direction once before settling at the target.
		boundaries.append(approach_end * (1.0 - 2.0 * 1.70158 / (3.0 * 2.70158)))
	# Split an update at phase boundaries so a long frame follows the actual
	# path instead of sweeping diagonally across a change of direction.
	var elapsed := 0.0
	while remaining > 0.00000001 and not is_queued_for_deletion():
		var step := remaining
		for boundary in boundaries:
			if boundary > age + 0.00000001: step = minf(step, boundary - age)
		_motion = _position_at(age + step) - _position_at(age)
		age += step
		_advance_physics(step, elapsed / delta, (elapsed + step) / delta)
		elapsed += step
		remaining -= step
	queue_redraw()


func _motion_for_step(_step: float) -> Vector2:
	return _motion


func _position_at(time: float) -> Vector2:
	var duration := maxf(approach_duration, 0.0)
	var progress := clampf(time / duration, 0.0, 1.0) if duration > 0.0 else 1.0
	if approach_ease == ApproachEase.SMOOTH:
		progress = progress * progress * (3.0 - 2.0 * progress)
	elif approach_ease == ApproachEase.BACK_OUT:
		var t := progress - 1.0
		progress = 1.0 + 2.70158 * t * t * t + 1.70158 * t * t
	var recoil_time := maxf(recoil_duration, 0.0) if recoil_distance > 0.0 else 0.0
	var since_launch := maxf(0.0, time - _launch_time())
	var recoil_progress := clampf(since_launch / recoil_time, 0.0, 1.0) if recoil_time > 0.0 else 0.0
	recoil_progress = recoil_progress * recoil_progress * (3.0 - 2.0 * recoil_progress)
	var recoil := -launch_velocity.normalized() * maxf(recoil_distance, 0.0) * recoil_progress
	var launched_for := maxf(0.0, since_launch - recoil_time)
	return _start_position.lerp(rest_position, progress) + recoil + launch_velocity * launched_for


func _launch_time() -> float:
	var delay := maxf(hold_duration, 0.0)
	return delay + (maxf(approach_duration, 0.0) if launch_timing == LaunchTiming.AFTER_APPROACH else 0.0)


func _draw() -> void:
	var colors := [Color.WHITE, Color.CYAN, Color.ORANGE, Color.LIME_GREEN]
	draw_circle(Vector2.ZERO, radius, colors[rule])
