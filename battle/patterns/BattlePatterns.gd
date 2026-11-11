class_name BattlePatterns extends RefCounted

# Positions are battle coordinates; velocities and durations use seconds.
static func bone(battle: Battle, at: Vector2, length: float, velocity: Vector2, rule := BattleBullet.Rule.WHITE, angle := 0.0, lifetime := 6.0, show_outside := false) -> PatternBullet:
	var result := PatternBullet.new()
	result.length = length
	result.velocity = velocity
	result.rule = rule
	result.rotation = angle
	result.lifetime = lifetime
	result.destroy_on_contact = false
	battle.spawn_bullet(result, at, show_outside)
	return result


static func wall(battle: Battle, start: Vector2, count: int, spacing: Vector2, length: float, velocity: Vector2, rule := BattleBullet.Rule.WHITE) -> Array[PatternBullet]:
	var result: Array[PatternBullet] = []
	for i in range(count):
		result.append(bone(battle, start + spacing * i, length, velocity, rule))
	return result


static func beam(battle: Battle, from: Vector2, direction: Vector2, warning := 0.7, duration := 0.8, width := 16.0, rule := BattleBullet.Rule.WHITE) -> PatternBullet:
	var result := PatternBullet.new()
	result.shape_type = PatternBullet.Shape.BEAM
	result.length = 600.0
	result.width = width
	result.velocity = Vector2.ZERO
	result.warning = warning
	result.lifetime = warning + duration
	result.destroy_on_contact = false
	result.rule = rule
	result.rotation = direction.angle()
	battle.spawn_bullet(result, from + direction.normalized() * result.length / 2.0)
	return result


static func blaster(battle: Battle, from: Vector2, target: Vector2, charge := 0.8, duration := 0.8) -> PatternBullet:
	var direction := (target - from).normalized()
	var head := BlasterHead.new()
	head.position = from
	head.rotation = direction.angle()
	head.charge = charge
	head.duration = duration
	battle.effects.add_child(head)
	return beam(battle, from, direction, charge, duration, 22.0)


static func line_bomb(battle: Battle, at: Vector2, lines: int, warning := 0.8, duration := 0.6) -> void:
	for i in range(maxi(lines, 1)):
		var direction := Vector2.RIGHT.rotated(PI * i / maxi(lines, 1))
		beam(battle, at - direction * 300.0, direction, warning, duration)


static func pellet(battle: Battle, at: Vector2, target: Vector2, pause := 0.5, speed := 180.0, lifetime := 5.0) -> PatternBullet:
	var result := PatternBullet.new()
	result.shape_type = PatternBullet.Shape.PELLET
	result.width = 6.0
	result.warning = pause
	result.velocity = Vector2.ZERO
	result.launch_velocity = (target - at).normalized() * speed
	result.lifetime = lifetime
	battle.spawn_bullet(result, at)
	return result


static func knife_warning(battle: Battle, from: Vector2, target: Vector2, warning := 0.5, duration := 0.35) -> PatternBullet:
	return beam(battle, from, (target - from).normalized(), warning, duration, 8.0)


static func ring(battle: Battle, at: Vector2, count: int, radius: float, length: float, angular_speed: float, lifetime := 6.0) -> BoneRing:
	var result := BoneRing.new()
	result.position = at
	result.angular_velocity = angular_speed
	result.lifetime = lifetime
	battle.bullets.add_child(result)
	for i in range(count):
		var part := PatternBullet.new()
		part.length = length
		part.velocity = Vector2.ZERO
		part.lifetime = lifetime
		part.destroy_on_contact = false
		part.position = Vector2.RIGHT.rotated(TAU * i / count) * radius
		part.rotation = TAU * i / count + PI / 2.0
		result.add_child(part)
	return result


static func platform(battle: Battle, at: Vector2, width: float, velocity := Vector2.ZERO, lifetime := 6.0) -> BattlePlatform:
	var result := BattlePlatform.new()
	result.position = at
	result.platform_width = width
	result.velocity = velocity
	result.lifetime = lifetime
	result.arena = battle.soul.arena
	battle.bullets.add_child(result)
	return result


static func pulse(battle: Battle, at: Vector2, expansion_speed := 90.0, lifetime := 4.0) -> PatternBullet:
	var result := PatternBullet.new()
	result.shape_type = PatternBullet.Shape.PULSE
	result.velocity = Vector2.ZERO
	result.expansion_speed = expansion_speed
	result.destroy_on_contact = false
	result.lifetime = lifetime
	battle.spawn_bullet(result, at)
	return result
