class_name BattleBullet extends Area2D

enum Rule { WHITE, BLUE, ORANGE, HEAL }
@export var velocity := Vector2(-115.0, 0.0)
@export var damage := 3
@export var lifetime := 6.0
@export var rule: Rule = Rule.WHITE
@export var karma := false
@export var karma_per_second := 6.0
@export var destroy_on_contact := true
@export var shootable := false:
	set(value):
		shootable = value
		if is_inside_tree():
			if value: add_to_group("shootable_bullets")
			else: remove_from_group("shootable_bullets")
@export var projectile_health := 1.0
var _contact_ticks: Dictionary = {}


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	if shootable:
		add_to_group("shootable_bullets")


func hit_by_soul_shot(amount: float) -> void:
	projectile_health -= amount
	if projectile_health <= 0.0:
		queue_free()


func _physics_process(delta: float) -> void:
	var step := minf(delta, maxf(lifetime, 0.0))
	var motion := _motion_for_step(step)
	var swept_exits: Dictionary = {}
	if motion.length_squared() > 16.0:
		swept_exits = _sweep_contacts(motion)
	if is_queued_for_deletion(): return
	position += motion
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	# A soul may start or stop moving while it remains inside a bullet.
	for area in get_overlapping_areas():
		if not swept_exits.has(area.get_instance_id()):
			_try_contact(area, delta)
	# An instantaneous crossing may never emit area_exited.
	for contact_id in swept_exits:
		_contact_ticks.erase(contact_id)


func _motion_for_step(step: float) -> Vector2:
	return velocity * step


func _sweep_contacts(local_motion: Vector2) -> Dictionary:
	var parent_2d := get_parent() as Node2D
	var world_motion := parent_2d.global_transform.basis_xform(local_motion) if parent_2d else local_motion
	var space := get_world_2d().direct_space_state
	var touched := {}
	var shapes: Array[CollisionShape2D] = []
	for child in get_children():
		if not child is CollisionShape2D or child.disabled or child.shape == null:
			continue
		shapes.append(child)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = child.shape
		query.transform = child.global_transform
		query.collision_mask = collision_mask
		query.collide_with_areas = true
		query.collide_with_bodies = false
		query.exclude = [get_rid()]
		# cast_motion skips objects that already overlap at the start.
		for hit in space.intersect_shape(query):
			if hit.collider is Area2D:
				touched[hit.collider.get_instance_id()] = true
				_try_contact(hit.collider)
		if is_queued_for_deletion(): return {}
		query.motion = world_motion
		var fractions := space.cast_motion(query)
		if fractions[1] < 1.0:
			var impact := minf(1.0, fractions[1] + 0.25 / maxf(world_motion.length(), 1.0))
			query.transform.origin += world_motion * impact
			query.motion = Vector2.ZERO
			for hit in space.intersect_shape(query):
				if hit.collider is Area2D:
					touched[hit.collider.get_instance_id()] = true
					_try_contact(hit.collider)
			if is_queued_for_deletion(): return {}
	if touched.is_empty(): return touched
	# Keep the contact if any of this bullet's shapes ends inside the area.
	for shape_node in shapes:
		var end_query := PhysicsShapeQueryParameters2D.new()
		end_query.shape = shape_node.shape
		end_query.transform = shape_node.global_transform.translated(world_motion)
		end_query.collision_mask = collision_mask
		end_query.collide_with_areas = true
		end_query.collide_with_bodies = false
		end_query.exclude = [get_rid()]
		for hit in space.intersect_shape(end_query):
			if hit.collider is Area2D: touched.erase(hit.collider.get_instance_id())
	return touched


func _draw() -> void:
	var colors := [Color.WHITE, Color.CYAN, Color.ORANGE, Color.LIME_GREEN]
	draw_circle(Vector2.ZERO, 6.0, colors[rule])


func _on_area_entered(area: Area2D) -> void:
	_try_contact(area)


func _on_area_exited(area: Area2D) -> void:
	_contact_ticks.erase(area.get_instance_id())


func _try_contact(area: Area2D, delta: float = 0.0) -> void:
	if is_queued_for_deletion(): return
	var soul := area.get_parent()
	if not soul is BattleSoul or not soul.movement_enabled:
		return
	if rule == Rule.BLUE and not soul.is_moving: return
	if rule == Rule.ORANGE and soul.is_moving: return
	if soul.blocks_bullet(global_position):
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
