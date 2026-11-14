extends Node2D

const Sweep := preload("res://battle/bullets/RotationSweep.gd")
var failures := 0
var target: Area2D


func _ready() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func crosses(shape: Shape2D, shape_offset: Transform2D, p0: Transform2D, p1: Transform2D, pa: float,
		b0: Transform2D, b1: Transform2D, ba: float, radius: float, start := 0.0, end := 1.0) -> bool:
	var segments: int = Sweep.subdivision_count(p0, p1, pa, b0, b1, ba, radius)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 4
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for i in range(segments + 1):
		var t := lerpf(start, end, float(i) / segments)
		query.transform = Sweep.pose(p0, p1, pa, b0, b1, ba, t) * shape_offset
		if not get_world_2d().direct_space_state.intersect_shape(query).is_empty(): return true
	return false


func move_target(at: Vector2) -> void:
	target.position = at
	await get_tree().physics_frame
	await get_tree().physics_frame


func run() -> void:
	target = Area2D.new()
	target.collision_layer = 4
	target.collision_mask = 0
	var target_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	target_shape.shape = circle
	target.add_child(target_shape)
	add_child(target)
	await get_tree().physics_frame
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 4)
	var id := Transform2D.IDENTITY
	var quarter := Transform2D(PI / 2.0, Vector2.ZERO)
	for fps in [30, 60, 144]:
		Engine.physics_ticks_per_second = fps
		await move_target(Vector2(20, 20))
		check(crosses(rect, id, id, id, 0, id, quarter, PI / 2, 31), "rotating rectangle hits between endpoints at %d Hz" % fps)
		await move_target(Vector2(25, 25))
		check(not crosses(rect, id, id, id, 0, id, quarter, PI / 2, 31), "rotating rectangle near-miss at %d Hz" % fps)
		var pellet := CircleShape2D.new()
		pellet.radius = 3
		var offset := Transform2D(0, Vector2(100, 0))
		await move_target(Vector2(70.71, 70.71))
		check(crosses(pellet, id, id, quarter, PI / 2, offset, offset, 0, 3), "orbit follows arc at %d Hz" % fps)
		await move_target(Vector2(50, 50))
		check(not crosses(pellet, id, id, quarter, PI / 2, offset, offset, 0, 3), "orbit avoids chord false hit at %d Hz" % fps)
		await move_target(Vector2(0, 100))
		check(crosses(pellet, id, id, id, TAU, offset, offset, 0, 3), "full positive turn at %d Hz" % fps)
		check(not crosses(pellet, id, id, id, TAU, offset, offset, 0, 3, 0.0, 0.15), "partial lifetime excludes later orbit at %d Hz" % fps)
		await move_target(Vector2(0, -100))
		check(crosses(pellet, id, id, id, -TAU * 2.0, offset, offset, 0, 3), "multiple negative turns at %d Hz" % fps)
		var child := CollisionShape2D.new()
		child.shape = pellet
		child.position = Vector2(20, 0)
		var child_radius: float = Sweep.collision_radius(child)
		check(child_radius >= 23.0, "sampling radius includes collision shape offset")
		await move_target(Vector2(14.14, 14.14))
		check(crosses(pellet, child.transform, id, id, 0, id, quarter, PI / 2, child_radius), "offset shape follows its local arc at %d Hz" % fps)
		child.free()
		var scaled0 := Transform2D(0, Vector2(2, 2), 0, Vector2.ZERO)
		var scaled1 := Transform2D(PI / 2, Vector2(2, 2), 0, Vector2.ZERO)
		await move_target(Vector2(141.42, 141.42))
		check(crosses(pellet, id, scaled0, scaled1, PI / 2, offset, offset, 0, 3), "scaled carrier follows its orbital arc at %d Hz" % fps)
	var root := Node2D.new()
	var parent := Node2D.new()
	root.add_child(parent)
	root.rotation = TAU * 2.0
	parent.rotation = -PI / 2.0
	check(is_equal_approx(Sweep.accumulated_rotation(parent), TAU * 2.0 - PI / 2.0), "ancestor angle preserves complete turns")
	root.free()
	var carrier_offset := Transform2D(0, Vector2(100, 0))
	check(Sweep.may_intersect(id, quarter, carrier_offset, carrier_offset, 3, Vector2(70, 70), Vector2(70, 70), 4), "broad phase retains the orbit hit")
	check(not Sweep.may_intersect(id, quarter, carrier_offset, carrier_offset, 3, Vector2(500, 500), Vector2(500, 500), 4), "broad phase rejects a distant target")
	check(not Sweep.may_intersect(id, quarter, carrier_offset, carrier_offset, 3, Vector2.ZERO, Vector2.ZERO, 4), "broad phase rejects a target inside the orbital hole")
	check(Sweep.may_intersect(id, quarter, carrier_offset, carrier_offset, 3, Vector2(500, 500), Vector2.ZERO, 4), "broad phase retains a moving target crossing the orbit")
	check(Sweep.subdivision_count(id, id, TAU * 1000, id, id, 0, 100) == Sweep.MAX_SUBDIVISIONS, "sampling is bounded")
	target.queue_free()
	await get_tree().process_frame
	if failures == 0: print("All rotational trajectory checks passed.")
	get_tree().quit(0 if failures == 0 else 1)
