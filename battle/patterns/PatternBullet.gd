class_name PatternBullet extends BattleBullet

enum Shape { BONE, BEAM, PULSE, PELLET }
var shape_type := Shape.BONE
var length := 50.0
var width := 8.0
var warning := 0.0
var age := 0.0
var angular_velocity := 0.0
var expansion_speed := 90.0
var radius := 2.0
var circle: CircleShape2D
var launch_velocity := Vector2.ZERO
var _motion_delay := 0.0
var _active_fraction := 0.0
var _pulse_active_radius := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	var collision := CollisionShape2D.new()
	if shape_type == Shape.PULSE or shape_type == Shape.PELLET:
		circle = CircleShape2D.new()
		circle.radius = radius + width if shape_type == Shape.PULSE else width
		collision.shape = circle
	else:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(width, length) if shape_type == Shape.BONE else Vector2(length, width)
		collision.shape = rect
	add_child(collision)
	super._ready()


func _physics_process(delta: float) -> void:
	var step := minf(delta, maxf(lifetime, 0.0))
	var previous_age := age
	age += step
	_active_fraction = clampf((warning - previous_age) / step, 0.0, 1.0) if step > 0.0 else 1.0
	rotation += angular_velocity * step
	if shape_type == Shape.PULSE:
		var previous_radius := radius
		radius += expansion_speed * step
		circle.radius = radius + width
		_pulse_active_radius = previous_radius + expansion_speed * clampf(warning - previous_age, 0.0, step)
	elif shape_type == Shape.PELLET and age >= warning:
		velocity = launch_velocity
		# Only integrate the part of this update after the warning expires.
		_motion_delay = clampf(warning - previous_age, 0.0, step)
	queue_redraw()
	super._physics_process(delta)


func _motion_for_step(step: float) -> Vector2:
	return velocity * maxf(0.0, step - _motion_delay)


func _sweep_active_start_fraction() -> float:
	return _active_fraction


func _motion_before_active_fraction(world_motion: Vector2, fraction: float) -> Vector2:
	if shape_type == Shape.PELLET and _motion_delay > 0.0: return Vector2.ZERO
	return world_motion * fraction


func _use_rotating_sweep() -> bool:
	# Own rotation does not alter a pulse ring, but a rotating parent can move
	# its center along an arc. That path needs the ring-specific sweep below.
	return shape_type != Shape.PULSE or _frame_parent_rotates


func _pulse_collision_enabled() -> bool:
	for child in get_children():
		if child is CollisionShape2D and not child.disabled and child.shape == circle: return true
	return false


func _sweep_contacts(world_motion: Vector2, start_offset: Vector2 = Vector2.ZERO, frame_start: float = 0.0, frame_end: float = 1.0) -> Dictionary:
	if shape_type != Shape.PULSE:
		return super._sweep_contacts(world_motion, start_offset, frame_start, frame_end)
	var touched := {}
	if not _pulse_collision_enabled(): return touched
	var center_start := global_position + start_offset
	for node in get_tree().get_nodes_in_group("battle_souls"):
		var soul := node as BattleSoul
		if not soul or soul.get_world_2d() != get_world_2d(): continue
		var hurtbox := soul.get_node_or_null("HurtBox") as Area2D
		if not hurtbox or not hurtbox.monitorable or (collision_mask & hurtbox.collision_layer) == 0 or soul.sweep_hurt_shapes().is_empty(): continue
		var soul_motion := soul_sweep_motion(soul)
		var soul_start := soul.global_position - soul_motion * (1.0 - frame_start)
		var interval_motion := soul_motion * (frame_end - frame_start)
		var relative_start := soul_start - center_start
		var relative_motion := interval_motion - world_motion
		var scale_factor := absf(global_scale.x)
		var thickness := maxf(width * scale_factor + 4.0, 0.0)
		var end_radius := radius * scale_factor
		var hit := _pulse_first_contact(relative_start, relative_motion, _pulse_active_radius * scale_factor, end_radius, thickness)
		if hit == INF: continue
		_sweep_bullet_position = center_start + world_motion * hit
		_sweep_soul_position = soul_start + interval_motion * hit
		# The matching ring position is at `hit`, not at the end-of-frame radius.
		super._try_contact(hurtbox)
		_sweep_bullet_position = null
		_sweep_soul_position = null
		if is_queued_for_deletion(): return {}
		if absf((relative_start + relative_motion).length() - end_radius) > thickness:
			touched[hurtbox.get_instance_id()] = true
	return touched


func _sweep_rotating_contacts(parent_from: Transform2D, parent_to: Transform2D,
		local_from: Transform2D, local_to: Transform2D, local_angle: float, frame_start: float, frame_end: float) -> Dictionary:
	if shape_type != Shape.PULSE:
		return super._sweep_rotating_contacts(parent_from, parent_to, local_from, local_to, local_angle, frame_start, frame_end)
	var touched := {}
	if not _pulse_collision_enabled(): return touched
	var scale_factor := absf(global_scale.x)
	var thickness := maxf(width * scale_factor + 4.0, 0.0)
	var from_radius := _pulse_active_radius * scale_factor
	var to_radius := radius * scale_factor
	var segments: int = RotationSweep.chain_subdivision_count(_frame_parent_chain_from, _frame_parent_chain_to, local_from, local_to, local_angle, 0.0)
	for node in get_tree().get_nodes_in_group("battle_souls"):
		var soul := node as BattleSoul
		if not soul or soul.get_world_2d() != get_world_2d(): continue
		var hurtbox := soul.get_node_or_null("HurtBox") as Area2D
		if not hurtbox or not hurtbox.monitorable or (collision_mask & hurtbox.collision_layer) == 0 or soul.sweep_hurt_shapes().is_empty(): continue
		var soul_motion := soul_sweep_motion(soul)
		var soul_start := soul.global_position - soul_motion * (1.0 - frame_start)
		var interval_motion := soul_motion * (frame_end - frame_start)
		var first_hit := INF
		for i in range(segments):
			var t0 := float(i) / segments
			var t1 := float(i + 1) / segments
			var center0 := _rotation_pose(local_from, local_to, local_angle, frame_start, frame_end, t0).origin
			var center1 := _rotation_pose(local_from, local_to, local_angle, frame_start, frame_end, t1).origin
			var relative_start := soul_start + interval_motion * t0 - center0
			var relative_motion := interval_motion * (t1 - t0) - (center1 - center0)
			var hit := _pulse_first_contact(relative_start, relative_motion, lerpf(from_radius, to_radius, t0), lerpf(from_radius, to_radius, t1), thickness)
			if hit != INF:
				first_hit = lerpf(t0, t1, hit)
				break
		if first_hit == INF: continue
		_sweep_bullet_position = _rotation_pose(local_from, local_to, local_angle, frame_start, frame_end, first_hit).origin
		_sweep_soul_position = soul_start + interval_motion * first_hit
		super._try_contact(hurtbox)
		_sweep_bullet_position = null
		_sweep_soul_position = null
		if is_queued_for_deletion(): return {}
		var end_center := _rotation_pose(local_from, local_to, local_angle, frame_start, frame_end, 1.0).origin
		if absf((soul_start + interval_motion - end_center).length() - to_radius) > thickness:
			touched[hurtbox.get_instance_id()] = true
	return touched


func _overlaps_soul_at(area: Area2D, bullet_offset: Vector2, frame_end: float) -> bool:
	if shape_type != Shape.PULSE:
		return super._overlaps_soul_at(area, bullet_offset, frame_end)
	if not _pulse_collision_enabled(): return false
	var soul := area.get_parent() as BattleSoul
	if not soul or area != soul.get_node_or_null("HurtBox") or soul.sweep_hurt_shapes().is_empty(): return false
	var soul_position := soul.global_position - soul_sweep_motion(soul) * (1.0 - frame_end)
	var scale_factor := absf(global_scale.x)
	var center := global_position + bullet_offset
	if _current_rotation_end_pose != null: center = _current_rotation_end_pose.origin
	return absf(soul_position.distance_to(center) - radius * scale_factor) <= width * scale_factor + 4.0


func _pulse_first_contact(start: Vector2, motion: Vector2, from_radius: float, to_radius: float, thickness: float) -> float:
	# In the pulse's reference frame, both the soul and the ring radius move
	# linearly. Solve |start + motion*t| = radius(t) +/- thickness directly;
	# finite temporal sampling can skip a thin ring at very high speeds.
	var start_gap := start.length() - from_radius
	if absf(start_gap) <= thickness: return 0.0
	var boundary := from_radius + (thickness if start_gap > thickness else -thickness)
	var change := to_radius - from_radius
	# Compute with scalar floats to avoid rounding the dot products to Vector2's
	# component precision before solving the quadratic.
	var px := float(start.x)
	var py := float(start.y)
	var vx := float(motion.x)
	var vy := float(motion.y)
	var a := vx * vx + vy * vy - change * change
	var b := 2.0 * (px * vx + py * vy - boundary * change)
	var c := px * px + py * py - boundary * boundary
	var roots: Array[float] = []
	if absf(a) < 0.000000000001:
		if absf(b) >= 0.000000000001: roots.append(-c / b)
	else:
		var discriminant := b * b - 4.0 * a * c
		if discriminant < 0.0: return INF
		var root := sqrt(discriminant)
		var q := -0.5 * (b + (root if b >= 0.0 else -root))
		if absf(q) < 0.000000000001:
			roots.append(-b / (2.0 * a))
		else:
			roots.append(q / a)
			roots.append(c / q)
	roots.sort()
	for t in roots:
		if t >= 0.0 and t <= 1.0 and boundary + change * t >= 0.0: return t
	return INF


func _try_contact(area: Area2D, delta: float = 0.0) -> void:
	if age < warning: return
	if shape_type == Shape.PULSE:
		if not _pulse_collision_enabled(): return
		var scale_factor := absf(global_scale.x)
		if absf(area.global_position.distance_to(global_position) - radius * scale_factor) > width * scale_factor + 4.0: return
	super._try_contact(area, delta)


func _draw() -> void:
	var colors := [Color.WHITE, Color.CYAN, Color.ORANGE, Color.LIME_GREEN]
	var color: Color = colors[rule]
	if shape_type == Shape.PELLET:
		draw_circle(Vector2.ZERO, width, color if age >= warning else Color(1.0, 0.7, 0.2, 0.7))
	elif age < warning:
		draw_line(Vector2(-length/2, 0), Vector2(length/2, 0), Color(1, 0.2, 0.2, 0.7), 2.0)
	elif shape_type == Shape.PULSE:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, color, width)
	elif shape_type == Shape.BONE:
		draw_rect(Rect2(-width/2, -length/2, width, length), color)
		for y in [-length/2, length/2]:
			draw_circle(Vector2(-width*0.35, y), width*0.55, color)
			draw_circle(Vector2(width*0.35, y), width*0.55, color)
	else:
		draw_rect(Rect2(-length/2, -width/2, length, width), color)
