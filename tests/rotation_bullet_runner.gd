extends "res://tests/test_runner.gd"

class OneFrameRing extends BoneRing:
	var armed := false

	func _physics_process(delta: float) -> void:
		if armed:
			armed = false
			super._physics_process(delta)


class OneFrameReparent extends Node:
	var armed := false
	var bullet: BattleBullet
	var target: Node
	var world_velocity := Vector2.ZERO
	var spin_velocity := 0.0

	func _physics_process(_delta: float) -> void:
		if armed:
			armed = false
			bullet.reparent(target, true)
			var basis := (target as Node2D).global_transform if target is Node2D else Transform2D.IDENTITY
			bullet.velocity = basis.basis_xform_inv(world_velocity)
			if bullet is PatternBullet: bullet.angular_velocity = spin_velocity


class CountingCone extends BoneCone:
	var sampled_poses := 0

	func _rotation_pose(local_from: Transform2D, local_to: Transform2D, local_angle: float,
			frame_start: float, frame_end: float, fraction: float) -> Transform2D:
		sampled_poses += 1
		return super._rotation_pose(local_from, local_to, local_angle, frame_start, frame_end, fraction)


func _ready() -> void:
	call_deferred("run_rotation_checks")


func run_rotation_checks() -> void:
	var old_tick_rate := Engine.physics_ticks_per_second
	var old_player: Dictionary = Global.player_data.duplicate(true)
	DebugService.invincible = false
	Global.player_data.armor = ""
	Global.player_data.def = 0
	Global.player_data.hp_max = 20
	Global.player_data.kr_enabled = false
	for fps in [30, 60, 144]:
		Engine.physics_ticks_per_second = fps
		await get_tree().create_timer(0.2).timeout
		await self_rotation_case(fps, Vector2(20, 20), 0.0, 17, "crosses between orientations")
		await self_rotation_case(fps, Vector2(25, 25), 0.0, 20, "does not hit a near miss")
		await self_rotation_case(fps, Vector2(20, 20), 1.0 / fps, 20, "does not hit during its warning")
		await self_rotation_case(fps, Vector2(10.72, 25.87), 0.5 / fps, 20, "ignores contact before warning expires")
		await self_rotation_case(fps, Vector2(25.87, 10.72), 0.5 / fps, 17, "detects contact after warning expires")
		await warning_crossing_case(fps, 0.75, 20)
		await warning_crossing_case(fps, 0.25, 17)
		await orbit_case(fps, PI / 2, 1.0, Vector2(70.71, 70.71), 17, "follows the carrier arc")
		await orbit_case(fps, PI / 2, 1.0, Vector2(50, 50), 20, "does not hit along the orbit chord")
		await orbit_case(fps, TAU, 1.0, Vector2(0, 100), 17, "detects a complete turn")
		await orbit_case(fps, -TAU, 1.0, Vector2(0, -100), 17, "detects a reverse complete turn")
		await orbit_case(fps, PI / 2, 0.5, Vector2(92.39, 38.27), 17, "detects an orbit before expiry")
		await orbit_case(fps, PI / 2, 0.5, Vector2(38.27, 92.39), 20, "ignores an orbit after expiry")
		await nested_orbit_case(fps, false, Vector2(70.71, 70.71), 17)
		await nested_orbit_case(fps, true, Vector2(85.36, 35.36), 17)
		await top_level_case(fps)
		for target_rotation in [0.0, PI / 2]:
			await reparent_case(fps, target_rotation, Vector2.ZERO, 20, "keep world position")
			await reparent_case(fps, target_rotation, Vector2(-200 * fps, 0), 17, "actual motion after reparent")
		await reparent_spin_case(fps, 0.0, 20)
		await reparent_spin_case(fps, -PI / 2 * fps, 17)
		await reparent_spin_case(fps, -TAU * fps, 17)
		await reparent_spin_case(fps, 0.0, 20, true)
		await reparent_spin_case(fps, -PI / 2 * fps, 17, true)
		await reparent_spin_case(fps, -TAU * fps, 17, true)
		await rotating_shield_case(fps, Vector2.RIGHT, 20)
		await rotating_shield_case(fps, Vector2.UP, 17)
		await rotating_shield_threshold_case(fps, -2.49, 20)
		await rotating_shield_threshold_case(fps, -2.30, 17)
		await rotating_spawn_case(fps)
		await beam_after_expiry_case(fps)
		await beam_departure_before_warning_case(fps)
		await cone_substep_case(fps, Vector2(92.39, 38.27), 17, "first substep")
		await cone_substep_case(fps, Vector2(38.27, 92.39), 17, "second substep")
		await moving_cone_arc_case(fps, Vector2(90.03, 37.29), 17, "arc hit")
		await moving_cone_arc_case(fps, Vector2(63.66, 63.66), 20, "chord near miss")
		await moving_cone_arc_case(fps, Vector2(48.72, 9.69), 17, "arc before expiry", 0.5)
		await moving_cone_arc_case(fps, Vector2(117.63, 78.60), 20, "arc after expiry", 0.5)
		await accelerating_cone_arc_case(fps)
		for soul_first in [true, false]:
			await live_ring_case(fps, soul_first, -29.29, 17, "synchronized crossing")
			await live_ring_case(fps, soul_first, 20.0, 20, "different-time near miss")
	await extreme_rotation_budget_case()
	Engine.physics_ticks_per_second = old_tick_rate
	Global.player_data = old_player
	Global.player_data_items.assign(old_player.items)
	Global.player_data.items = Global.player_data_items
	if failures.is_empty(): print("All integrated rotation checks passed.")
	else: print("Failed integrated rotation checks: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func make_soul(at: Vector2) -> BattleSoul:
	Global.player_set_hp(20)
	var soul: BattleSoul = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
	soul.position = at
	soul.movement_enabled = false
	add_child(soul)
	soul.set_physics_process(false)
	return soul


func self_rotation_case(fps: int, at: Vector2, warning: float, expected_hp: int, label: String) -> void:
	var soul := make_soul(at)
	var bullet := PatternBullet.new()
	bullet.shape_type = PatternBullet.Shape.BONE
	bullet.length = 60
	bullet.width = 4
	bullet.velocity = Vector2.ZERO
	bullet.angular_velocity = -PI / 2 * fps
	bullet.warning = warning
	bullet.destroy_on_contact = false
	add_child(bullet)
	bullet.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	soul.movement_enabled = true
	bullet._physics_process(1.0 / fps)
	check(Global.player_data.hp == expected_hp, "self rotation %s at %d Hz (HP=%d)" % [label, fps, Global.player_data.hp])
	soul.queue_free()
	if is_instance_valid(bullet): bullet.queue_free()
	await get_tree().process_frame


func warning_crossing_case(fps: int, warning_fraction: float, expected_hp: int) -> void:
	var soul := make_soul(Vector2.ZERO)
	var bullet := PatternBullet.new()
	bullet.shape_type = PatternBullet.Shape.BONE
	bullet.length = 4
	bullet.width = 4
	bullet.position = Vector2(-100, 0)
	bullet.velocity = Vector2(200 * fps, 0)
	bullet.warning = warning_fraction / fps
	bullet.destroy_on_contact = false
	add_child(bullet)
	bullet.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	soul.movement_enabled = true
	bullet._physics_process(1.0 / fps)
	check(Global.player_data.hp == expected_hp, "linear crossing respects %.2f-frame warning at %d Hz (HP=%d)" % [warning_fraction, fps, Global.player_data.hp])
	soul.queue_free()
	if is_instance_valid(bullet): bullet.queue_free()
	await get_tree().process_frame


func orbit_case(fps: int, angle: float, life_steps: float, at: Vector2, expected_hp: int, label: String) -> void:
	var soul := make_soul(at)
	var carrier := Node2D.new()
	add_child(carrier)
	var bullet := PatternBullet.new()
	bullet.shape_type = PatternBullet.Shape.PELLET
	bullet.width = 3
	bullet.position = Vector2(100, 0)
	bullet.velocity = Vector2.ZERO
	bullet.lifetime = life_steps / fps
	bullet.destroy_on_contact = false
	carrier.add_child(bullet)
	bullet.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	soul.movement_enabled = true
	carrier.rotation += angle
	bullet._physics_process(1.0 / fps)
	check(Global.player_data.hp == expected_hp, "parent rotation %s at %d Hz (HP=%d)" % [label, fps, Global.player_data.hp])
	soul.queue_free()
	carrier.queue_free()
	await get_tree().process_frame


func nested_orbit_case(fps: int, counter_rotate: bool, at: Vector2, expected_hp: int) -> void:
	var soul := make_soul(at)
	var pivot := Node2D.new()
	add_child(pivot)
	var carrier := Node2D.new()
	carrier.position = Vector2(50, 0)
	pivot.add_child(carrier)
	var bullet := PatternBullet.new()
	bullet.shape_type = PatternBullet.Shape.PELLET
	bullet.width = 3
	bullet.position = Vector2(50, 0)
	bullet.velocity = Vector2.ZERO
	bullet.destroy_on_contact = false
	carrier.add_child(bullet)
	bullet.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	soul.movement_enabled = true
	pivot.rotation = PI / 2
	if counter_rotate: carrier.rotation = -PI / 2
	bullet._physics_process(1.0 / fps)
	check(Global.player_data.hp == expected_hp, "nested parent rotation with counter_rotate=%s at %d Hz (HP=%d)" % [counter_rotate, fps, Global.player_data.hp])
	soul.queue_free()
	pivot.queue_free()
	await get_tree().process_frame


func top_level_case(fps: int) -> void:
	var soul := make_soul(Vector2(70.71, 70.71))
	var carrier := Node2D.new()
	add_child(carrier)
	var bullet := PatternBullet.new()
	bullet.top_level = true
	bullet.shape_type = PatternBullet.Shape.PELLET
	bullet.width = 3
	bullet.position = Vector2(100, 0)
	bullet.velocity = Vector2.ZERO
	bullet.destroy_on_contact = false
	carrier.add_child(bullet)
	bullet.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	soul.movement_enabled = true
	carrier.rotation = PI / 2
	bullet._physics_process(1.0 / fps)
	check(Global.player_data.hp == 20, "top-level bullet ignores parent rotation at %d Hz" % fps)
	soul.queue_free()
	carrier.queue_free()
	await get_tree().process_frame


func rotating_shield_case(fps: int, shield: Vector2, expected_hp: int) -> void:
	var soul := make_soul(Vector2(0, 100))
	soul.set_mode("green")
	soul.shield_direction = shield
	var carrier := Node2D.new()
	add_child(carrier)
	var bullet := PatternBullet.new()
	bullet.shape_type = PatternBullet.Shape.PELLET
	bullet.width = 3
	bullet.position = Vector2(100, 0)
	bullet.velocity = Vector2.ZERO
	bullet.destroy_on_contact = false
	carrier.add_child(bullet)
	bullet.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	soul.movement_enabled = true
	carrier.rotation = PI / 2
	bullet._physics_process(1.0 / fps)
	check(Global.player_data.hp == expected_hp, "green shield %s on rotating bullet at %d Hz (HP=%d)" % [shield, fps, Global.player_data.hp])
	soul.queue_free()
	carrier.queue_free()
	await get_tree().process_frame


func reparent_case(fps: int, target_rotation: float, world_velocity: Vector2, expected_hp: int, label: String) -> void:
	var soul := make_soul(Vector2.ZERO)
	soul.movement_enabled = true
	var from := Node2D.new()
	from.position = Vector2(-200, 0)
	add_child(from)
	var target := Node2D.new()
	target.position = Vector2(200, 0)
	target.rotation = target_rotation
	add_child(target)
	var bullet := PatternBullet.new()
	bullet.shape_type = PatternBullet.Shape.BONE
	bullet.length = 6
	bullet.width = 4
	bullet.position = Vector2(350, 0)
	bullet.velocity = Vector2.ZERO
	bullet.destroy_on_contact = false
	from.add_child(bullet)
	var driver := OneFrameReparent.new()
	driver.bullet = bullet
	driver.target = target
	driver.world_velocity = world_velocity
	add_child(driver)
	for frame in range(3): await get_tree().physics_frame
	driver.armed = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_instance_valid(bullet): bullet.set_physics_process(false)
	check(Global.player_data.hp == expected_hp, "reparent %s to angle %.2f at %d Hz (HP=%d)" % [label, target_rotation, fps, Global.player_data.hp])
	soul.queue_free()
	from.queue_free()
	target.queue_free()
	driver.queue_free()
	await get_tree().process_frame


func reparent_spin_case(fps: int, spin: float, expected_hp: int, plain_parent := false) -> void:
	var soul := make_soul(Vector2(170, 20))
	soul.movement_enabled = true
	var from := Node2D.new()
	from.position = Vector2(-200, 0)
	add_child(from)
	var target: Node = Node.new() if plain_parent else Node2D.new()
	if target is Node2D:
		target.position = Vector2(200, 0)
		target.rotation = PI / 2
	add_child(target)
	var bullet := PatternBullet.new()
	bullet.shape_type = PatternBullet.Shape.BONE
	bullet.length = 60
	bullet.width = 4
	bullet.position = Vector2(350, 0)
	bullet.velocity = Vector2.ZERO
	bullet.destroy_on_contact = false
	from.add_child(bullet)
	var driver := OneFrameReparent.new()
	driver.bullet = bullet
	driver.target = target
	driver.spin_velocity = spin
	add_child(driver)
	for frame in range(3): await get_tree().physics_frame
	driver.armed = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_instance_valid(bullet): bullet.set_physics_process(false)
	check(Global.player_data.hp == expected_hp, "reparent with spin %.2f at %d Hz (plain parent=%s, HP=%d)" % [spin, fps, plain_parent, Global.player_data.hp])
	soul.queue_free()
	from.queue_free()
	target.queue_free()
	driver.queue_free()
	await get_tree().process_frame


func rotating_spawn_case(fps: int) -> void:
	var soul := make_soul(Vector2(70.71, 70.71))
	soul.movement_enabled = true
	await get_tree().physics_frame
	# This motion happened before the bullet existed.
	soul.global_position = Vector2(500, 500)
	var carrier := Node2D.new()
	add_child(carrier)
	var bullet := PatternBullet.new()
	bullet.shape_type = PatternBullet.Shape.PELLET
	bullet.width = 3
	bullet.position = Vector2(100, 0)
	bullet.velocity = Vector2.ZERO
	bullet.destroy_on_contact = false
	carrier.add_child(bullet)
	bullet.set_physics_process(false)
	carrier.rotation = PI / 2
	bullet._physics_process(1.0 / fps)
	check(Global.player_data.hp == 20, "rotating bullet ignores soul motion before spawn at %d Hz" % fps)
	soul.queue_free()
	carrier.queue_free()
	await get_tree().process_frame


func rotating_shield_threshold_case(fps: int, y: float, expected_hp: int) -> void:
	var soul := make_soul(Vector2.ZERO)
	soul.set_mode("green")
	soul.shield_direction = Vector2.UP
	var bullet := PatternBullet.new()
	bullet.shape_type = PatternBullet.Shape.PELLET
	bullet.width = 0.5
	bullet.position = Vector2(10, y)
	bullet.launch_velocity = Vector2(-20 * fps, 0)
	bullet.angular_velocity = fps * 0.5
	bullet.destroy_on_contact = false
	add_child(bullet)
	bullet.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	soul.movement_enabled = true
	bullet._physics_process(1.0 / fps)
	check(Global.player_data.hp == expected_hp, "rotating sweep locates green shield contact at y=%.2f and %d Hz (HP=%d)" % [y, fps, Global.player_data.hp])
	soul.queue_free()
	if is_instance_valid(bullet): bullet.queue_free()
	await get_tree().process_frame


func beam_after_expiry_case(fps: int) -> void:
	var soul := make_soul(Vector2(-100, 0))
	soul.speed = 100.0 * fps
	soul.arena = Rect2(-1000, -1000, 2000, 2000)
	var beam := PatternBullet.new()
	beam.shape_type = PatternBullet.Shape.BEAM
	beam.length = 10.0
	beam.width = 4.0
	beam.velocity = Vector2.ZERO
	beam.warning = 0.25 / fps
	beam.lifetime = 0.5 / fps
	beam.destroy_on_contact = false
	add_child(beam)
	beam.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	soul.movement_enabled = true
	soul.set_physics_process(true)
	beam.set_physics_process(true)
	Input.action_press("ui_right")
	await get_tree().physics_frame
	await get_tree().process_frame
	Input.action_release("ui_right")
	soul.set_physics_process(false)
	check(Global.player_data.hp == 20, "beam ignores soul arriving after expiry at %d Hz (HP=%d)" % [fps, Global.player_data.hp])
	soul.queue_free()
	if is_instance_valid(beam): beam.queue_free()
	await get_tree().process_frame


func beam_departure_before_warning_case(fps: int) -> void:
	var soul := make_soul(Vector2.ZERO)
	soul.speed = 100.0 * fps
	soul.arena = Rect2(-1000, -1000, 2000, 2000)
	var beam := PatternBullet.new()
	beam.shape_type = PatternBullet.Shape.BEAM
	beam.length = 10.0
	beam.width = 4.0
	beam.velocity = Vector2.ZERO
	beam.warning = 0.25 / fps
	beam.lifetime = 0.5 / fps
	beam.destroy_on_contact = false
	add_child(beam)
	beam.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	soul.movement_enabled = true
	soul.set_physics_process(true)
	beam.set_physics_process(true)
	Input.action_press("ui_right")
	await get_tree().physics_frame
	await get_tree().process_frame
	Input.action_release("ui_right")
	soul.set_physics_process(false)
	check(Global.player_data.hp == 20, "beam ignores soul departing before warning at %d Hz (HP=%d)" % [fps, Global.player_data.hp])
	soul.queue_free()
	if is_instance_valid(beam): beam.queue_free()
	await get_tree().process_frame


func cone_substep_case(fps: int, at: Vector2, expected_hp: int, label: String) -> void:
	var soul := make_soul(at)
	var carrier := Node2D.new()
	add_child(carrier)
	var cone := BoneCone.new()
	cone.position = Vector2(100, 0)
	cone.length = 6
	cone.width = 4
	cone.target_angle = PI / 2
	cone.turn_speed = PI / 2 * fps
	cone.charge_duration = 0.5 / fps
	cone.acceleration = 0
	carrier.add_child(cone)
	cone.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	soul.movement_enabled = true
	carrier.rotation = PI / 2
	cone._physics_process(1.0 / fps)
	check(Global.player_data.hp == expected_hp, "bone cone %s follows its carrier during substeps at %d Hz (HP=%d)" % [label, fps, Global.player_data.hp])
	soul.queue_free()
	carrier.queue_free()
	await get_tree().process_frame


func moving_cone_arc_case(fps: int, at: Vector2, expected_hp: int, label: String, lifetime_steps: float = 1.0) -> void:
	var soul := make_soul(at)
	var cone := BoneCone.new()
	cone.length = 6
	cone.width = 4
	cone.target_angle = PI / 2
	cone.turn_speed = PI / 2 * fps
	cone.charge_duration = 0
	cone.speed = 200.0 * fps
	cone.acceleration = 0
	cone.lifetime = lifetime_steps / fps
	cone.destroy_on_contact = false
	add_child(cone)
	cone.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	soul.movement_enabled = true
	cone._physics_process(1.0 / fps)
	check(Global.player_data.hp == expected_hp, "turning moving cone %s at %d Hz (HP=%d)" % [label, fps, Global.player_data.hp])
	soul.queue_free()
	if is_instance_valid(cone): cone.queue_free()
	await get_tree().process_frame


func accelerating_cone_arc_case(fps: int) -> void:
	var soul := make_soul(Vector2(42.55, 24.60))
	var cone := BoneCone.new()
	cone.length = 6
	cone.width = 4
	cone.target_angle = PI / 2
	cone.turn_speed = PI / 2 * fps
	cone.charge_duration = 0
	cone.speed = 0
	cone.acceleration = 400.0 * fps * fps
	cone.destroy_on_contact = false
	add_child(cone)
	cone.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	soul.movement_enabled = true
	cone._physics_process(1.0 / fps)
	check(Global.player_data.hp == 17, "accelerating turning cone follows its arc at %d Hz (HP=%d)" % [fps, Global.player_data.hp])
	soul.queue_free()
	if is_instance_valid(cone): cone.queue_free()
	await get_tree().process_frame


func live_ring_case(fps: int, soul_first: bool, start_y: float, expected_hp: int, label: String) -> void:
	var soul: BattleSoul
	if soul_first: soul = make_soul(Vector2(70.71, start_y))
	var carrier := OneFrameRing.new()
	carrier.angular_velocity = PI / 2 * fps
	add_child(carrier)
	var bullet := PatternBullet.new()
	bullet.shape_type = PatternBullet.Shape.PELLET
	bullet.width = 3
	bullet.position = Vector2(100, 0)
	bullet.destroy_on_contact = false
	carrier.add_child(bullet)
	if not soul_first: soul = make_soul(Vector2(70.71, start_y))
	soul.arena = Rect2(-1000, -1000, 2000, 2000)
	soul.speed = 200.0 * fps
	soul.set_physics_process(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	soul.movement_enabled = true
	carrier.armed = true
	Input.action_press("ui_down")
	await get_tree().physics_frame
	await get_tree().process_frame
	Input.action_release("ui_down")
	soul.set_physics_process(false)
	check(Global.player_data.hp == expected_hp,
		"live BoneRing and moving soul %s, soul_first=%s at %d Hz (HP=%d)" % [label, soul_first, fps, Global.player_data.hp])
	soul.queue_free()
	carrier.queue_free()
	await get_tree().process_frame


func extreme_rotation_budget_case() -> void:
	var soul := make_soul(Vector2(110, 0))
	var carrier := Node2D.new()
	add_child(carrier)
	var cone := CountingCone.new()
	cone.length = 6
	cone.width = 4
	cone.position = Vector2(100, 0)
	cone.velocity = Vector2.ZERO
	carrier.add_child(cone)
	cone.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	soul.movement_enabled = true
	carrier.rotation = 512 * TAU
	var start_us := Time.get_ticks_usec()
	for i in range(512):
		cone._advance_physics(1.0 / (60 * 512), float(i) / 512, float(i + 1) / 512)
	var duration_us := Time.get_ticks_usec() - start_us
	check(cone.sampled_poses > 0 and cone.sampled_poses <= 2050,
		"512 rapid-turn substeps keep rotation pose queries bounded (got %d)" % cone.sampled_poses)
	print("Extreme 512-substep rotation: ", cone.sampled_poses, " poses in ", duration_us, " us")
	soul.queue_free()
	carrier.queue_free()
	await get_tree().process_frame
