class_name SoulProjectile extends Node2D

var velocity := Vector2.UP * 360.0
var lifetime := 2.0
var damage := 1.0
var battle: Battle
var _shot_shape: CircleShape2D
var _default_enemy_shape: CircleShape2D
var _previous_transforms := {}
var _shootable_revisions := {}
var _polygon_cache := {}


func _ready() -> void:
	# Observe normal battle-object physics updates before testing relative motion.
	process_physics_priority = 100
	_shot_shape = CircleShape2D.new()
	_shot_shape.radius = 3.0
	_default_enemy_shape = CircleShape2D.new()
	_default_enemy_shape.radius = 12.0
	for target in get_tree().get_nodes_in_group("shootable_bullets"):
		if target is BattleBullet:
			_previous_transforms[target.get_instance_id()] = target.global_transform
			_shootable_revisions[target.get_instance_id()] = target._shootable_revision
	if is_instance_valid(battle):
		for enemy in battle.battle_get_enemys():
			_previous_transforms[enemy.get_instance_id()] = enemy.global_transform


func _physics_process(delta: float) -> void:
	if lifetime <= 0.0:
		queue_free()
		return
	var previous := global_position
	var step := minf(delta, maxf(lifetime, 0.0))
	var motion := velocity * step
	var target_time_fraction := step / delta if delta > 0.0 else 0.0
	lifetime -= delta
	var first_fraction := INF
	var first_bullet: BattleBullet
	var first_enemy: BattleEnemy
	for bullet in get_tree().get_nodes_in_group("shootable_bullets"):
		if not bullet is BattleBullet or bullet.is_queued_for_deletion(): continue
		var current: Transform2D = bullet.global_transform
		var id := bullet.get_instance_id()
		var prior: Transform2D = _previous_transforms.get(id, current)
		if _shootable_revisions.get(id, bullet._shootable_revision) != bullet._shootable_revision:
			prior = bullet._shootable_activation_transform
		_previous_transforms[id] = current
		_shootable_revisions[id] = bullet._shootable_revision
		var fraction := INF
		for child in bullet.get_children():
			var shapes: Array[Shape2D] = []
			if child is CollisionShape2D and not child.disabled and child.shape != null:
				shapes.append(child.shape)
			elif child is CollisionPolygon2D and not child.disabled:
				shapes = _polygon_shapes(child)
			else:
				continue
			var old_shape: Transform2D = prior * current.affine_inverse() * child.global_transform
			var target_motion: Vector2 = (child.global_transform.origin - old_shape.origin) * target_time_fraction
			for shape in shapes:
				fraction = minf(fraction, _contact_fraction(previous, motion, shape, old_shape, target_motion))
		if fraction < first_fraction:
			first_fraction = fraction
			first_bullet = bullet
	if is_instance_valid(battle):
		for enemy in battle.battle_get_enemys():
			if not enemy.projectile_target or enemy.is_queued_for_deletion(): continue
			var current: Transform2D = enemy.global_transform
			var prior: Transform2D = _previous_transforms.get(enemy.get_instance_id(), current)
			_previous_transforms[enemy.get_instance_id()] = current
			var old_shape := prior.translated_local(enemy.projectile_hit_offset)
			var current_shape := current.translated_local(enemy.projectile_hit_offset)
			var shape: Shape2D = enemy.projectile_hit_shape if enemy.projectile_hit_shape else _default_enemy_shape
			var fraction := _contact_fraction(previous, motion, shape, old_shape, (current_shape.origin - old_shape.origin) * target_time_fraction)
			if fraction < first_fraction:
				first_fraction = fraction
				first_enemy = enemy
				first_bullet = null
	if first_fraction < INF:
		global_position = previous + motion * first_fraction
		if first_bullet: first_bullet.hit_by_soul_shot(damage)
		else: battle.damage_enemy_from_projectile(first_enemy, damage)
		queue_free()
		return
	global_position = previous + motion
	if lifetime <= 0.0: queue_free()


func _polygon_shapes(polygon_node: CollisionPolygon2D) -> Array[Shape2D]:
	var key := polygon_node.get_instance_id()
	var points := polygon_node.polygon
	var mode := polygon_node.build_mode
	if _polygon_cache.has(key):
		var cached: Dictionary = _polygon_cache[key]
		if cached.points == points and cached.mode == mode: return cached.shapes
	var shapes: Array[Shape2D] = []
	if mode == CollisionPolygon2D.BUILD_SEGMENTS:
		for i in range(points.size() if points.size() >= 2 else 0):
			var segment := SegmentShape2D.new()
			segment.a = points[i]
			segment.b = points[(i + 1) % points.size()]
			shapes.append(segment)
	elif points.size() >= 3:
		for part in Geometry2D.decompose_polygon_in_convex(points):
			var convex := ConvexPolygonShape2D.new()
			convex.points = part
			shapes.append(convex)
	_polygon_cache[key] = {"points": points.duplicate(), "mode": mode, "shapes": shapes}
	return shapes


func _contact_fraction(start: Vector2, motion: Vector2, shape: Shape2D, target_transform: Transform2D, target_motion: Vector2) -> float:
	var shot_transform := Transform2D(0.0, start)
	if _shot_shape.collide(shot_transform, shape, target_transform): return 0.0
	# Use a shared time parameter for both objects. Sweeping both shapes
	# independently can report paths that cross at different moments.
	var relative_motion := motion - target_motion
	if not _shot_shape.collide_with_motion(shot_transform, relative_motion, shape, target_transform, Vector2.ZERO): return INF
	# The overlap predicate is monotone over the swept prefix, allowing the
	# earliest impact to be compared across different target shapes.
	var low := 0.0
	var high := 1.0
	for iteration in range(14):
		var middle := (low + high) / 2.0
		if _shot_shape.collide_with_motion(shot_transform, relative_motion * middle, shape, target_transform, Vector2.ZERO):
			high = middle
		else:
			low = middle
	return high


func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color.YELLOW)
