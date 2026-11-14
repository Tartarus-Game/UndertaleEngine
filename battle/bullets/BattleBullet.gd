class_name BattleBullet extends Area2D

const RotationSweep = preload("res://battle/bullets/RotationSweep.gd")

enum Rule { WHITE, BLUE, ORANGE, HEAL }
@export var velocity := Vector2(-115.0, 0.0)
@export var damage := 3
@export var lifetime := 6.0
@export var rule: Rule = Rule.WHITE
@export var karma := false
@export var karma_per_second := 6.0
@export var destroy_on_contact := true
@export var grazeable := true
var _shootable_revision := 0
var _shootable_activation_transform := Transform2D.IDENTITY
@export var shootable := false:
	set(value):
		if value != shootable:
			_shootable_revision += 1
			if value and is_inside_tree(): _shootable_activation_transform = global_transform
		shootable = value
		if is_inside_tree():
			if value: add_to_group("shootable_bullets")
			else: remove_from_group("shootable_bullets")
@export var projectile_health := 1.0
var _contact_ticks: Dictionary = {}
var _previous_parent_position := Vector2.ZERO
var _frame_parent_motion := Vector2.ZERO
var _frame_parent_origin_linear := true
var _previous_parent_chain := []
var _frame_parent_chain_from := []
var _frame_parent_chain_to := []
var _frame_parent_rotates := false
var _previous_local_transform := Transform2D.IDENTITY
var _previous_local_rotation := 0.0
var _current_rotation_end_pose: Variant = null
var _sweep_bullet_position: Variant = null
var _sweep_soul_position: Variant = null
var _spawn_frame := -1
var _spawn_soul_positions := {}


func _ready() -> void:
	# Evaluate after the soul and ordinary moving parents, regardless of tree order.
	if process_physics_priority == 0: process_physics_priority = 50
	_spawn_frame = Engine.get_physics_frames()
	for node in get_tree().get_nodes_in_group("battle_souls"):
		if node is BattleSoul:
			_spawn_soul_positions[node.get_instance_id()] = node.global_position
	var parent_2d := get_parent() as Node2D
	if top_level: parent_2d = null
	if parent_2d:
		_previous_parent_position = parent_2d.global_position
		_previous_parent_chain = RotationSweep.capture_chain(parent_2d)
	_previous_local_transform = transform
	_previous_local_rotation = rotation
	# Layer 5 is reserved for the optional graze sensor.
	set_collision_layer_value(5, true)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	if shootable:
		_shootable_activation_transform = global_transform
		add_to_group("shootable_bullets")


func hit_by_soul_shot(amount: float) -> void:
	projectile_health -= amount
	if projectile_health <= 0.0:
		queue_free()


func _physics_process(delta: float) -> void:
	_advance_physics(delta)


func _advance_physics(delta: float, frame_start: float = 0.0, frame_end: float = 1.0) -> void:
	if lifetime <= 0.0:
		queue_free()
		return
	var step := minf(maxf(delta, 0.0), lifetime)
	if step <= 0.0: return
	var motion := _motion_for_step(step)
	var live_end := lerpf(frame_start, frame_end, step / delta)
	var parent_2d := get_parent() as Node2D
	if top_level: parent_2d = null
	if parent_2d and frame_start == 0.0:
		_frame_parent_chain_to = RotationSweep.capture_chain(parent_2d)
		if RotationSweep.same_chain(_previous_parent_chain, _frame_parent_chain_to):
			_frame_parent_motion = parent_2d.global_position - _previous_parent_position
			_frame_parent_chain_from = _previous_parent_chain
		else:
			# Reparenting changes local coordinates without necessarily moving the
			# bullet in world space. Never treat the distance between two unrelated
			# parent origins as motion of the bullet.
			_frame_parent_motion = Vector2.ZERO
			_frame_parent_chain_from = _frame_parent_chain_to
			_reset_local_sweep_for_parent(parent_2d.global_transform)
		_previous_parent_position = parent_2d.global_position
		_frame_parent_rotates = RotationSweep.chain_has_rotation(_frame_parent_chain_from, _frame_parent_chain_to)
		_frame_parent_origin_linear = RotationSweep.chain_origin_is_linear(_frame_parent_chain_from, _frame_parent_chain_to)
		_previous_parent_chain = _frame_parent_chain_to
	elif frame_start == 0.0:
		if not _previous_parent_chain.is_empty():
			_reset_local_sweep_for_parent(Transform2D.IDENTITY)
			_previous_parent_chain = []
		_frame_parent_motion = Vector2.ZERO
		_frame_parent_chain_from = []
		_frame_parent_chain_to = []
		_frame_parent_rotates = false
		_frame_parent_origin_linear = true
	var own_world_motion := parent_2d.global_transform.basis_xform(motion) if parent_2d else motion
	# The parent has already moved this tick. Each substep uses only its own
	# slice of that movement, clipped to the bullet's remaining lifetime.
	var live_parent_motion := _frame_parent_motion * (live_end - frame_start)
	var world_motion := live_parent_motion + own_world_motion
	var active_from := clampf(_sweep_active_start_fraction(), 0.0, 1.0)
	var swept_exits: Dictionary = {}
	if monitoring and active_from < 1.0:
		var before_active := live_parent_motion * active_from + _motion_before_active_fraction(own_world_motion, active_from)
		var active_frame := lerpf(frame_start, live_end, active_from)
		var local_angle := rotation - _previous_local_rotation
		if _use_rotating_sweep() and (not is_zero_approx(local_angle) or _frame_parent_rotates):
			var parent_from := RotationSweep.chain_pose(_frame_parent_chain_from, _frame_parent_chain_to, active_frame)
			var parent_to := RotationSweep.chain_pose(_frame_parent_chain_from, _frame_parent_chain_to, live_end)
			var local_to := transform
			local_to.origin += motion
			var local_from := RotationSweep._interpolate_transform(_previous_local_transform, transform, local_angle, active_from)
			local_from.origin += _motion_before_active_fraction(motion, active_from)
			var interval_local_angle := local_angle * (1.0 - active_from)
			_current_rotation_end_pose = parent_to * local_to
			swept_exits = _sweep_rotating_contacts(parent_from, parent_to, local_from, local_to, interval_local_angle, active_frame, live_end)
		else:
			swept_exits = _sweep_contacts(world_motion - before_active, -_frame_parent_motion * (1.0 - frame_start) + before_active, active_frame, live_end)
	if is_queued_for_deletion(): return
	position += motion
	_previous_local_transform = transform
	_previous_local_rotation = rotation
	lifetime = maxf(0.0, lifetime - step)
	# A soul may start or stop moving while it remains inside a bullet.
	if monitoring and active_from < 1.0:
		for area in get_overlapping_areas():
			if not swept_exits.has(area.get_instance_id()) and _overlaps_soul_at(area, -_frame_parent_motion * (1.0 - live_end), live_end):
				_try_contact(area, step * (1.0 - active_from))
	elif not monitoring:
		_contact_ticks.clear()
	# An instantaneous crossing may never emit area_exited.
	for contact_id in swept_exits:
		_contact_ticks.erase(contact_id)
	_current_rotation_end_pose = null
	# Process contacts for the live part of the last tick before removing the bullet.
	if lifetime <= 0.0: queue_free()


func _reset_local_sweep_for_parent(parent_pose: Transform2D) -> void:
	var old_parent_pose := RotationSweep.chain_pose(_previous_parent_chain, _previous_parent_chain, 1.0)
	var old_local := parent_pose.affine_inverse() * old_parent_pose * _previous_local_transform
	_previous_local_rotation = old_local.get_rotation()
	# Reparenting is an instantaneous change; keep the current local origin,
	# while preserving the prior world orientation for this frame's own spin.
	old_local.origin = transform.origin
	_previous_local_transform = old_local


func _motion_for_step(step: float) -> Vector2:
	return velocity * step


func _sweep_active_start_fraction() -> float:
	return 0.0


func _use_rotating_sweep() -> bool:
	return true


func _motion_before_active_fraction(world_motion: Vector2, fraction: float) -> Vector2:
	return world_motion * fraction


func is_graze_active() -> bool:
	return true


func soul_sweep_motion(soul: BattleSoul) -> Vector2:
	# A bullet created partway through a tick cannot hit a soul along a path
	# the soul already travelled before this bullet entered the scene tree.
	if _spawn_frame == Engine.get_physics_frames():
		var id := soul.get_instance_id()
		if _spawn_soul_positions.has(id):
			return soul.global_position - _spawn_soul_positions[id]
	elif not _spawn_soul_positions.is_empty():
		_spawn_soul_positions.clear()
	return soul.sweep_motion()


func _sweep_contacts(world_motion: Vector2, start_offset: Vector2 = Vector2.ZERO, frame_start: float = 0.0, frame_end: float = 1.0) -> Dictionary:
	var touched := {}
	for node in get_tree().get_nodes_in_group("battle_souls"):
		var soul := node as BattleSoul
		if not soul or soul.get_world_2d() != get_world_2d(): continue
		var hurtbox := soul.get_node_or_null("HurtBox") as Area2D
		if not hurtbox or (collision_mask & hurtbox.collision_layer) == 0: continue
		var soul_motion := soul_sweep_motion(soul)
		var interval_motion := soul_motion * (frame_end - frame_start)
		var relative_motion := world_motion - interval_motion
		# The physics server can report an overlap one tick after a node spawns.
		# Check a new stationary contact ourselves before a short lifetime expires.
		if relative_motion.length_squared() <= 0.000000000001 and get_overlapping_areas().has(hurtbox): continue
		var first_hit := INF
		var ends_overlapping := false
		for child in get_children():
			if not child is CollisionShape2D or child.disabled or child.shape == null: continue
			var bullet_start: Transform2D = child.global_transform.translated(start_offset)
			for target in soul.sweep_hurt_shapes():
				var shape: Shape2D = target.shape
				var target_start: Transform2D = target.transform.translated(-soul_motion * (1.0 - frame_start))
				# Bounding rectangles are conservative under linear translation. Avoid
				# expensive shape queries for the many bullets far from the soul.
				var bounds: Rect2 = bullet_start * child.shape.get_rect()
				var swept_bounds := bounds.merge(Rect2(bounds.position + relative_motion, bounds.size)).grow(0.01)
				var target_bounds: Rect2 = target_start * shape.get_rect()
				if not swept_bounds.intersects(target_bounds, true): continue
				if child.shape.collide_with_motion(bullet_start, relative_motion, shape, target_start, Vector2.ZERO):
					# Locate first contact for directional shields. Both shapes advance on
					# the same clock; sweeping them independently would give false hits.
					var high := 1.0
					if soul.has_mode("green"):
						var low := 0.0
						for i in range(16):
							var middle := (low + high) * 0.5
							if child.shape.collide_with_motion(bullet_start, relative_motion * middle, shape, target_start, Vector2.ZERO): high = middle
							else: low = middle
					first_hit = minf(first_hit, high)
					var bullet_end := bullet_start.translated(world_motion)
					var target_end := target_start.translated(interval_motion)
					if child.shape.collide(bullet_end, shape, target_end): ends_overlapping = true
		if first_hit == INF: continue
		_sweep_bullet_position = global_position + start_offset + world_motion * first_hit
		_sweep_soul_position = soul.global_position - soul_motion * (1.0 - frame_start) + interval_motion * first_hit
		_try_contact(hurtbox)
		_sweep_bullet_position = null
		_sweep_soul_position = null
		if is_queued_for_deletion(): return {}
		if not ends_overlapping: touched[hurtbox.get_instance_id()] = true
	return touched


func _sweep_rotating_contacts(parent_from: Transform2D, parent_to: Transform2D,
		local_from: Transform2D, local_to: Transform2D, local_angle: float, frame_start: float, frame_end: float) -> Dictionary:
	var touched := {}
	# Only bound the current substep's ancestor motion. Bounding the entire
	# frame for every cone substep could multiply the work by hundreds.
	var chain_from := RotationSweep.chain_at(_frame_parent_chain_from, _frame_parent_chain_to, frame_start)
	var chain_to := RotationSweep.chain_at(_frame_parent_chain_from, _frame_parent_chain_to, frame_end)
	for node in get_tree().get_nodes_in_group("battle_souls"):
		var soul := node as BattleSoul
		if not soul or soul.get_world_2d() != get_world_2d(): continue
		var hurtbox := soul.get_node_or_null("HurtBox") as Area2D
		if not hurtbox or (collision_mask & hurtbox.collision_layer) == 0: continue
		var soul_motion := soul_sweep_motion(soul)
		var interval_motion := soul_motion * (frame_end - frame_start)
		var soul_start := soul.global_position - soul_motion * (1.0 - frame_start)
		var targets := soul.sweep_hurt_shapes()
		var target_radius := 0.0
		for target in targets:
			var target_shape: Shape2D = target.shape
			var bounds: Rect2 = target.transform * target_shape.get_rect()
			for x in [bounds.position.x, bounds.end.x]:
				for y in [bounds.position.y, bounds.end.y]:
					target_radius = maxf(target_radius, Vector2(x, y).distance_to(soul.global_position))
		var first_hit := INF
		var ends_overlapping := false
		for child in get_children():
			if not child is CollisionShape2D or child.disabled or child.shape == null: continue
			var radius := RotationSweep.collision_radius(child)
			if _frame_parent_origin_linear and not RotationSweep.may_intersect(parent_from, parent_to, local_from, local_to, radius, soul_start, soul_start + interval_motion, target_radius): continue
			var segments: int = RotationSweep.chain_subdivision_count(chain_from, chain_to, local_from, local_to, local_angle, radius)
			# Opposite bullet and soul motion add in the relative frame.
			segments = mini(RotationSweep.substep_budget(frame_start, frame_end), segments + ceili(interval_motion.length() / RotationSweep.MAX_POINT_TRAVEL))
			for target in targets:
				var shape: Shape2D = target.shape
				var target_start: Transform2D = target.transform.translated(-soul_motion * (1.0 - frame_start))
				var bullet_end: Transform2D = parent_to * local_to * child.transform
				if child.shape.collide(bullet_end, shape, target_start.translated(interval_motion)): ends_overlapping = true
				for i in range(segments):
					var t0 := float(i) / segments
					if t0 >= first_hit: break
					var t1 := float(i + 1) / segments
					var bullet_start: Transform2D = _rotation_pose(local_from, local_to, local_angle, frame_start, frame_end, t0) * child.transform
					var bullet_next: Transform2D = _rotation_pose(local_from, local_to, local_angle, frame_start, frame_end, t1) * child.transform
					var target_pose := target_start.translated(interval_motion * t0)
					var relative_motion := bullet_next.origin - bullet_start.origin - interval_motion * (t1 - t0)
					if child.shape.collide_with_motion(bullet_start, relative_motion, shape, target_pose, Vector2.ZERO):
						var hit_fraction := 0.0
						if soul.has_mode("green") and not child.shape.collide(bullet_start, shape, target_pose):
							var low := 0.0
							var high := 1.0
							for iteration in range(16):
								var middle := (low + high) * 0.5
								if child.shape.collide_with_motion(bullet_start, relative_motion * middle, shape, target_pose, Vector2.ZERO): high = middle
								else: low = middle
							hit_fraction = high
						first_hit = minf(first_hit, lerpf(t0, t1, hit_fraction))
						break
				# A final instantaneous overlap can be missed by an orientation held
				# at the start of the last segment.
				if ends_overlapping: first_hit = minf(first_hit, 1.0)
		if first_hit == INF: continue
		_sweep_bullet_position = _rotation_pose(local_from, local_to, local_angle, frame_start, frame_end, first_hit).origin
		_sweep_soul_position = soul_start + interval_motion * first_hit
		_try_contact(hurtbox)
		_sweep_bullet_position = null
		_sweep_soul_position = null
		if is_queued_for_deletion(): return {}
		if not ends_overlapping: touched[hurtbox.get_instance_id()] = true
	return touched


func _rotation_pose(local_from: Transform2D, local_to: Transform2D, local_angle: float,
		frame_start: float, frame_end: float, fraction: float) -> Transform2D:
	var parent := RotationSweep.chain_pose(_frame_parent_chain_from, _frame_parent_chain_to, lerpf(frame_start, frame_end, fraction))
	return parent * RotationSweep._interpolate_transform(local_from, local_to, local_angle, fraction)


func _overlaps_soul_at(area: Area2D, bullet_offset: Vector2, frame_end: float) -> bool:
	var soul := area.get_parent() as BattleSoul
	if not soul or area != soul.get_node_or_null("HurtBox"): return false
	var soul_offset := -soul_sweep_motion(soul) * (1.0 - frame_end)
	for child in get_children():
		if not child is CollisionShape2D or child.disabled or child.shape == null: continue
		var bullet_transform: Transform2D = child.global_transform.translated(bullet_offset)
		if _current_rotation_end_pose != null: bullet_transform = _current_rotation_end_pose * child.transform
		for target in soul.sweep_hurt_shapes():
			var shape: Shape2D = target.shape
			if child.shape.collide(bullet_transform, shape, target.transform.translated(soul_offset)): return true
	return false


func _draw() -> void:
	var colors := [Color.WHITE, Color.CYAN, Color.ORANGE, Color.LIME_GREEN]
	draw_circle(Vector2.ZERO, 6.0, colors[rule])


func _on_area_entered(area: Area2D) -> void:
	_try_contact(area)


func _on_area_exited(area: Area2D) -> void:
	_contact_ticks.erase(area.get_instance_id())


func _try_contact(area: Area2D, delta: float = 0.0) -> void:
	if not monitoring or is_queued_for_deletion(): return
	var soul := area.get_parent()
	if not soul is BattleSoul or not soul.movement_enabled:
		return
	if rule == Rule.BLUE and not soul.is_moving_for_collision(): return
	if rule == Rule.ORANGE and soul.is_moving_for_collision(): return
	var bullet_position: Vector2 = _sweep_bullet_position if _sweep_bullet_position != null else global_position
	var soul_position: Vector2 = _sweep_soul_position if _sweep_soul_position != null else soul.global_position
	if soul.blocks_bullet_at(bullet_position, soul_position):
		if destroy_on_contact: queue_free()
		return
	var applied := false
	var contact_id := area.get_instance_id()
	if rule == Rule.HEAL:
		if not _contact_ticks.has(contact_id):
			Global.player_heal(damage)
			_contact_ticks[contact_id] = 0.0
			applied = true
	elif karma or bool(Global.player_data.kr_enabled):
		if not _contact_ticks.has(contact_id):
			_contact_ticks[contact_id] = 0.0
			applied = soul.take_karma(damage)
		else:
			var accumulated := float(_contact_ticks[contact_id]) + karma_per_second * delta
			var amount := floori(accumulated + 0.000001)
			_contact_ticks[contact_id] = maxf(0.0, accumulated - amount)
			if amount > 0: applied = soul.take_karma(amount)
	else:
		applied = soul.take_damage(damage)
	if applied and destroy_on_contact:
		queue_free()
