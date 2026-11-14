## Builds time-aligned poses for a rotating bullet and its parent. Godot's
## cast_motion cannot rotate a shape; callers must query these poses, and can
## use the same fractions to interpolate another moving object's position.
extends RefCounted

const MAX_POINT_TRAVEL := 2.0 # pixels between requested poses
const MAX_ANGLE_STEP := PI / 24.0
const MAX_SUBDIVISIONS := 512


## Allocate the per-frame sample budget proportionally across attack substeps.
## Rounding permits at most one extra segment per substep.
static func substep_budget(frame_start: float, frame_end: float) -> int:
	return clampi(ceili(MAX_SUBDIVISIONS * maxf(0.0, frame_end - frame_start)), 1, MAX_SUBDIVISIONS)


## Record local poses from the outermost Node2D to the immediate parent.
## Retaining the unwrapped angle on every node preserves counter-rotating
## ancestors and orbital paths that cannot be inferred from global endpoints.
static func capture_chain(node: Node2D) -> Array:
	var result := []
	var current := node
	while is_instance_valid(current):
		result.push_front({"id": current.get_instance_id(), "transform": current.transform, "rotation": current.rotation})
		if current.top_level: break
		current = current.get_parent() as Node2D
	return result


static func same_chain(from: Array, to: Array) -> bool:
	if from.size() != to.size(): return false
	for i in range(from.size()):
		if from[i].id != to[i].id: return false
	return true


static func chain_pose(from: Array, to: Array, t: float) -> Transform2D:
	var result := Transform2D.IDENTITY
	for i in range(to.size()):
		result *= _interpolate_transform(from[i].transform, to[i].transform, to[i].rotation - from[i].rotation, t)
	return result


static func chain_at(from: Array, to: Array, t: float) -> Array:
	var result := []
	for i in range(to.size()):
		var angle: float = to[i].rotation - from[i].rotation
		result.append({"id": to[i].id, "transform": _interpolate_transform(from[i].transform, to[i].transform, angle, t), "rotation": lerpf(from[i].rotation, to[i].rotation, t)})
	return result


static func chain_has_rotation(from: Array, to: Array) -> bool:
	for i in range(to.size()):
		if not is_zero_approx(to[i].rotation - from[i].rotation): return true
	return false


## The immediate parent's origin travels linearly only while all ancestor
## bases remain unchanged. Any ancestor rotation or scale change can bend it.
static func chain_origin_is_linear(from: Array, to: Array) -> bool:
	for i in range(to.size() - 1):
		var a: Transform2D = from[i].transform
		var b: Transform2D = to[i].transform
		if not is_zero_approx(to[i].rotation - from[i].rotation) or not a.x.is_equal_approx(b.x) or not a.y.is_equal_approx(b.y): return false
	return true


static func _scale_bound(pose: Transform2D) -> float:
	var scale := pose.get_scale().abs()
	return maxf(scale.x, scale.y) if is_zero_approx(pose.get_skew()) else scale.length()


## Conservative path-length estimate for all ancestors. This deliberately
## counts opposite rotations separately, even when their final angles cancel.
static func chain_subdivision_count(from: Array, to: Array, local_from: Transform2D,
		local_to: Transform2D, local_angle: float, radius: float) -> int:
	var local_scale := maxf(_scale_bound(local_from), _scale_bound(local_to))
	var extent := maxf(local_from.origin.length(), local_to.origin.length()) + radius * local_scale
	var travel := local_from.origin.distance_to(local_to.origin) + absf(local_angle) * radius * local_scale
	var max_angle := absf(local_angle)
	for i in range(to.size() - 1, -1, -1):
		var a: Transform2D = from[i].transform
		var b: Transform2D = to[i].transform
		var scale_bound := maxf(_scale_bound(a), _scale_bound(b))
		var angle := absf(to[i].rotation - from[i].rotation)
		travel = scale_bound * (travel + angle * extent) + a.origin.distance_to(b.origin)
		extent = maxf(a.origin.length(), b.origin.length()) + scale_bound * extent
		max_angle = maxf(max_angle, angle)
	return clampi(ceili(maxf(travel / MAX_POINT_TRAVEL, max_angle / MAX_ANGLE_STEP)), 1, MAX_SUBDIVISIONS)


## Node2D.rotation retains full turns, unlike Transform2D.get_rotation().
## Include Node2D ancestors so a carrier rotating through a full turn can be
## distinguished from a stationary carrier with the same final transform.
static func accumulated_rotation(node: Node2D) -> float:
	var result := 0.0
	var current := node
	while is_instance_valid(current):
		result += current.rotation
		if current.top_level: break
		current = current.get_parent() as Node2D
	return result


static func _interpolate_transform(from: Transform2D, to: Transform2D, angle_delta: float, t: float) -> Transform2D:
	return Transform2D(from.get_rotation() + angle_delta * t,
		from.get_scale().lerp(to.get_scale(), t), lerpf(from.get_skew(), to.get_skew(), t),
		from.origin.lerp(to.origin, t))


## parent_to and local_to represent the end of the selected time interval.
## Angles must describe the unwrapped change during that same interval.
static func pose(parent_from: Transform2D, parent_to: Transform2D, parent_angle_delta: float,
		local_from: Transform2D, local_to: Transform2D, local_angle_delta: float, t: float) -> Transform2D:
	return _interpolate_transform(parent_from, parent_to, parent_angle_delta, t) * \
		_interpolate_transform(local_from, local_to, local_angle_delta, t)


## Conservative extent of the shape's transformed bounding rectangle, from
## the bullet origin. This includes an offset CollisionShape2D's orbital path.
static func collision_radius(collision: CollisionShape2D) -> float:
	if collision.shape == null: return 0.0
	var bounds := collision.shape.get_rect()
	var result := 0.0
	for x in [bounds.position.x, bounds.end.x]:
		for y in [bounds.position.y, bounds.end.y]:
			result = maxf(result, (collision.transform * Vector2(x, y)).length())
	return result


## Conservative whole-interval broad phase when the parent origin translates
## linearly. target_radius must bound all target collision geometry around
## its recorded origin in world coordinates. A parent whose origin orbits a
## further ancestor needs a broader path bound, so callers must not use this
## shortcut unless the parent's origin path is known to be linear.
static func may_intersect(parent_from: Transform2D, parent_to: Transform2D,
		local_from: Transform2D, local_to: Transform2D, radius: float,
		target_from: Vector2, target_to: Vector2, target_radius: float) -> bool:
	var p0 := parent_from.get_scale().abs()
	var p1 := parent_to.get_scale().abs()
	var l0 := local_from.get_scale().abs()
	var l1 := local_to.get_scale().abs()
	# The Frobenius bound remains conservative with skew/non-uniform scale.
	var p_scale := maxf(p0.length(), p1.length())
	var l_scale := maxf(l0.length(), l1.length())
	var orbit_radius := maxf(local_from.origin.length(), local_to.origin.length()) + radius * l_scale
	var low := Vector2(minf(parent_from.origin.x, parent_to.origin.x), minf(parent_from.origin.y, parent_to.origin.y))
	var high := Vector2(maxf(parent_from.origin.x, parent_to.origin.x), maxf(parent_from.origin.y, parent_to.origin.y))
	var target_low := Vector2(minf(target_from.x, target_to.x), minf(target_from.y, target_to.y))
	var target_high := Vector2(maxf(target_from.x, target_to.x), maxf(target_from.y, target_to.y))
	var bullet_bounds := Rect2(low, high - low).grow(p_scale * orbit_radius)
	var target_bounds := Rect2(target_low, target_high - target_low).grow(target_radius)
	if not bullet_bounds.intersects(target_bounds, true): return false
	# With constant uniform parent scale, a bullet on an orbital path cannot
	# reach inside the path's inner radius. Relative target/parent translation
	# is linear, so its maximum distance occurs at an endpoint.
	if p0.x > 0.0 and is_equal_approx(p0.x, p0.y) and p0.is_equal_approx(p1) \
			and is_zero_approx(parent_from.get_skew()) and is_zero_approx(parent_to.get_skew()):
		var local_motion := local_to.origin - local_from.origin
		var closest_t := clampf(-local_from.origin.dot(local_motion) / local_motion.length_squared(), 0.0, 1.0) if not local_motion.is_zero_approx() else 0.0
		var inner_radius := (local_from.origin + local_motion * closest_t).length() - radius * l_scale
		var target_distance := maxf((target_from - parent_from.origin).length(), (target_to - parent_to.origin).length()) + target_radius
		if target_distance < inner_radius * p0.x: return false
	return true


## Radius is measured from the bullet origin to the furthest collision point
## in bullet-local coordinates. The returned count is bounded: if it reaches
## MAX_SUBDIVISIONS the requested spatial precision may not be achieved.
static func subdivision_count(parent_from: Transform2D, parent_to: Transform2D, parent_angle_delta: float,
		local_from: Transform2D, local_to: Transform2D, local_angle_delta: float, radius: float) -> int:
	var p0 := parent_from.get_scale().abs()
	var p1 := parent_to.get_scale().abs()
	var l0 := local_from.get_scale().abs()
	var l1 := local_to.get_scale().abs()
	var parent_scale := maxf(maxf(p0.x, p0.y), maxf(p1.x, p1.y))
	var local_scale := maxf(maxf(l0.x, l0.y), maxf(l1.x, l1.y))
	var local_radius := maxf(local_from.origin.length(), local_to.origin.length()) + radius * local_scale
	var travel := parent_from.origin.distance_to(parent_to.origin)
	travel += parent_scale * (local_from.origin.distance_to(local_to.origin) + absf(parent_angle_delta) * local_radius + absf(local_angle_delta) * radius * local_scale)
	var angular_steps := maxf(absf(parent_angle_delta), absf(local_angle_delta)) / MAX_ANGLE_STEP
	return clampi(ceili(maxf(travel / MAX_POINT_TRAVEL, angular_steps)), 1, MAX_SUBDIVISIONS)
