extends "res://tests/test_runner.gd"

func _ready() -> void:
	call_deferred("run_physics_checks")


func run_physics_checks() -> void:
	var old_tick_rate := Engine.physics_ticks_per_second
	var old_player: Dictionary = Global.player_data.duplicate(true)
	DebugService.invincible = false
	Global.player_data.armor = ""
	Global.player_data.def = 0
	Global.player_data.hp_max = 20
	Global.player_data.kr = 0.0
	Global.player_data.kr_enabled = false
	await test_platform_bounce()
	await test_fast_bullets()
	await test_bullet_lifetime()
	await test_repeated_fast_contact()
	await test_fast_pulse()
	await test_pellet_warning()
	await test_short_beams()
	await test_soul_projectile_order_and_lifetime()
	await test_soul_projectile_target_shapes()
	await test_shootable_polygon()
	await test_graze()
	await test_targeted_pellet()
	await test_pellet_parallel_and_recoil()
	await test_bone_cone()
	await test_gun_shot()
	await test_platform_carry()
	await test_jump_release()
	await test_gravity_directions()
	await test_ceiling_collision()
	Engine.physics_ticks_per_second = old_tick_rate
	Input.action_release("ui_up")
	Global.player_data = old_player
	Global.player_data_items.assign(old_player.items)
	Global.player_data.items = Global.player_data_items
	AudioManager.stop_all_sfx()
	await get_tree().create_timer(0.15).timeout
	if failures.is_empty(): print("All battle physics checks passed.")
	else: print("Failed battle physics checks: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func set_physics_rate(fps: int) -> void:
	Engine.physics_ticks_per_second = fps
	# Godot applies a changed rate after its current timing window.
	await get_tree().create_timer(0.25).timeout


func test_platform_bounce() -> void:
	for fps in [30, 60, 144]:
		await set_physics_rate(fps)
		var platform := BattlePlatform.new()
		platform.position = Vector2(180, 50)
		platform.platform_width = 20
		platform.velocity = Vector2(100, 0)
		platform.lifetime = 10
		platform.bounce_in_arena = true
		platform.arena = Rect2(0, 0, 200, 100)
		add_child(platform)
		for frame in range(fps / 2 + 1): await get_tree().physics_frame
		platform.set_physics_process(false)
		check(absf(platform.position.x - 150.0) < 5.0 and platform.velocity.x < 0, "platform reflects at its edge after 0.5 seconds at %d ticks/s (x=%.2f)" % [fps, platform.position.x])
		platform.queue_free()
		await get_tree().process_frame


func test_fast_bullets() -> void:
	for fps in [30, 60, 144]:
		await set_physics_rate(fps)
		for case in [
			{"start": -100, "rule": BattleBullet.Rule.WHITE, "expected": 17},
			{"start": 0, "rule": BattleBullet.Rule.WHITE, "expected": 17},
			{"start": -100, "rule": BattleBullet.Rule.BLUE, "expected": 20},
			{"start": -100, "rule": BattleBullet.Rule.ORANGE, "expected": 17},
		]:
			Global.player_set_hp(20)
			var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
			soul.arena = Rect2(-1000, -1000, 2000, 2000)
			soul.movement_enabled = true
			add_child(soul)
			await get_tree().physics_frame
			var bullet: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
			bullet.position = Vector2(case.start, 0)
			bullet.velocity = Vector2(12000, 0)
			bullet.lifetime = 10
			bullet.rule = case.rule
			add_child(bullet)
			for frame in range(6): await get_tree().physics_frame
			check(Global.player_data.hp == case.expected, "fast bullet obeys rule %d from x=%d at %d ticks/s (HP=%d)" % [case.rule, case.start, fps, Global.player_data.hp])
			soul.queue_free()
			if is_instance_valid(bullet): bullet.queue_free()
			await get_tree().process_frame


func test_bullet_lifetime() -> void:
	for fps in [30, 60, 144]:
		await set_physics_rate(fps)
		for bullet_lifetime in [0.005, 0.012]:
			Global.player_set_hp(20)
			var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
			soul.arena = Rect2(-1000, -1000, 2000, 2000)
			soul.movement_enabled = true
			add_child(soul)
			await get_tree().physics_frame
			var bullet: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
			bullet.position = Vector2(-100, 0)
			bullet.velocity = Vector2(12000, 0)
			bullet.lifetime = bullet_lifetime
			add_child(bullet)
			for frame in range(6): await get_tree().physics_frame
			var expected := 20 if bullet_lifetime == 0.005 else 17
			check(Global.player_data.hp == expected, "fast bullet honors %.3fs lifetime at %d ticks/s (HP=%d)" % [bullet_lifetime, fps, Global.player_data.hp])
			soul.queue_free()
			if is_instance_valid(bullet): bullet.queue_free()
			await get_tree().process_frame


func test_repeated_fast_contact() -> void:
	await set_physics_rate(30)
	Global.player_set_hp(10)
	var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
	soul.arena = Rect2(-1000, -1000, 2000, 2000)
	soul.movement_enabled = true
	add_child(soul)
	await get_tree().physics_frame
	var bullet: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
	bullet.position = Vector2(-100, 0)
	bullet.velocity = Vector2(12000, 0)
	bullet.rule = BattleBullet.Rule.HEAL
	bullet.destroy_on_contact = false
	add_child(bullet)
	for frame in range(3): await get_tree().physics_frame
	check(Global.player_data.hp == 13, "fast healing bullet applies on first crossing")
	bullet.position = Vector2(-100, 0)
	for frame in range(3): await get_tree().physics_frame
	check(Global.player_data.hp == 16, "fast healing bullet can apply again after leaving and crossing")
	soul.queue_free()
	bullet.queue_free()
	await get_tree().process_frame


func test_fast_pulse() -> void:
	for fps in [30, 60, 144]:
		await set_physics_rate(fps)
		Global.player_set_hp(20)
		var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
		soul.position = Vector2(50, 0)
		soul.arena = Rect2(-1000, -1000, 2000, 2000)
		soul.movement_enabled = true
		add_child(soul)
		await get_tree().physics_frame
		var pulse := PatternBullet.new()
		pulse.shape_type = PatternBullet.Shape.PULSE
		pulse.velocity = Vector2.ZERO
		pulse.expansion_speed = 6000.0
		pulse.destroy_on_contact = false
		add_child(pulse)
		for frame in range(6): await get_tree().physics_frame
		check(Global.player_data.hp == 17, "fast expanding pulse damages soul at %d ticks/s (HP=%d)" % [fps, Global.player_data.hp])
		soul.queue_free()
		pulse.queue_free()
		await get_tree().process_frame


func test_pellet_warning() -> void:
	await set_physics_rate(30)
	for soul_x in [-50.0, 50.0]:
		Global.player_set_hp(20)
		var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
		soul.position = Vector2(soul_x, 0)
		soul.arena = Rect2(-1000, -1000, 2000, 2000)
		soul.movement_enabled = true
		add_child(soul)
		await get_tree().physics_frame
		var pellet := PatternBullet.new()
		pellet.shape_type = PatternBullet.Shape.PELLET
		pellet.velocity = Vector2.ZERO
		pellet.launch_velocity = Vector2(12000, 0)
		pellet.warning = 0.025
		add_child(pellet)
		for frame in range(5): await get_tree().physics_frame
		var expected := 20 if soul_x < 0 else 17
		check(Global.player_data.hp == expected, "pellet travels only forward after warning (soul x=%.0f HP=%d)" % [soul_x, Global.player_data.hp])
		soul.queue_free()
		if is_instance_valid(pellet): pellet.queue_free()
		await get_tree().process_frame


func test_short_beams() -> void:
	for fps in [30, 60, 144]:
		await set_physics_rate(fps)
		for active in [true, false]:
			Global.player_set_hp(20)
			var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
			soul.arena = Rect2(-1000, -1000, 2000, 2000)
			soul.movement_enabled = true
			add_child(soul)
			await get_tree().physics_frame
			var beam := PatternBullet.new()
			beam.shape_type = PatternBullet.Shape.BEAM
			beam.velocity = Vector2.ZERO
			beam.warning = 0.001 if active else 0.003
			beam.lifetime = 0.002
			beam.destroy_on_contact = false
			add_child(beam)
			for frame in range(4): await get_tree().physics_frame
			var expected := 17 if active else 20
			check(Global.player_data.hp == expected, "short beam active=%s at %d ticks/s (HP=%d)" % [active, fps, Global.player_data.hp])
			soul.queue_free()
			if is_instance_valid(beam): beam.queue_free()
			await get_tree().process_frame


func test_soul_projectile_order_and_lifetime() -> void:
	for fps in [30, 60, 144]:
		var far: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
		far.position = Vector2(80, 0)
		far.velocity = Vector2.ZERO
		far.shootable = true
		add_child(far)
		far.set_physics_process(false)
		var near: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
		near.position = Vector2(30, 0)
		near.velocity = Vector2.ZERO
		near.shootable = true
		add_child(near)
		near.set_physics_process(false)
		var shot := SoulProjectile.new()
		shot.velocity = Vector2(12000, 0)
		add_child(shot)
		shot.set_physics_process(false)
		shot._physics_process(1.0 / fps)
		check(near.is_queued_for_deletion() and not far.is_queued_for_deletion(), "yellow projectile hits nearest target at %d ticks/s" % fps)
		if not near.is_queued_for_deletion(): near.queue_free()
		if not far.is_queued_for_deletion(): far.queue_free()
		if not shot.is_queued_for_deletion(): shot.queue_free()
		await get_tree().process_frame
		var target: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
		target.position = Vector2(80, 0)
		target.velocity = Vector2.ZERO
		target.shootable = true
		add_child(target)
		target.set_physics_process(false)
		shot = SoulProjectile.new()
		shot.velocity = Vector2(12000, 0)
		shot.lifetime = 0.005
		add_child(shot)
		shot.set_physics_process(false)
		shot._physics_process(1.0 / fps)
		check(not target.is_queued_for_deletion() and shot.is_queued_for_deletion(), "yellow projectile stops at lifetime boundary at %d ticks/s" % fps)
		if not target.is_queued_for_deletion(): target.queue_free()
		if not shot.is_queued_for_deletion(): shot.queue_free()
		await get_tree().process_frame
		var overlap: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
		overlap.velocity = Vector2.ZERO
		overlap.shootable = true
		add_child(overlap)
		overlap.set_physics_process(false)
		shot = SoulProjectile.new()
		shot.lifetime = 0.0
		add_child(shot)
		shot.set_physics_process(false)
		shot._physics_process(1.0 / fps)
		check(not overlap.is_queued_for_deletion() and shot.is_queued_for_deletion(), "expired yellow projectile cannot hit an overlapping target")
		if not overlap.is_queued_for_deletion(): overlap.queue_free()
		if not shot.is_queued_for_deletion(): shot.queue_free()
		await get_tree().process_frame


func test_soul_projectile_target_shapes() -> void:
	for fps in [30, 60, 144]:
		var bone := PatternBullet.new()
		bone.position = Vector2(50, 0)
		bone.velocity = Vector2.ZERO
		bone.length = 50.0
		bone.width = 8.0
		bone.shootable = true
		add_child(bone)
		bone.set_physics_process(false)
		var shot := SoulProjectile.new()
		shot.position = Vector2(0, 20)
		shot.velocity = Vector2(12000, 0)
		add_child(shot)
		shot.set_physics_process(false)
		shot._physics_process(1.0 / fps)
		check(bone.is_queued_for_deletion(), "yellow shot hits long bone away from its center at %d updates/s" % fps)
		if not bone.is_queued_for_deletion(): bone.queue_free()
		if not shot.is_queued_for_deletion(): shot.queue_free()
		await get_tree().process_frame
		var pellet := PatternBullet.new()
		pellet.shape_type = PatternBullet.Shape.PELLET
		pellet.position = Vector2(50, 0)
		pellet.velocity = Vector2.ZERO
		pellet.width = 4.0
		pellet.shootable = true
		add_child(pellet)
		pellet.set_physics_process(false)
		shot = SoulProjectile.new()
		shot.position = Vector2(0, 7.5)
		shot.velocity = Vector2(12000, 0)
		add_child(shot)
		shot.set_physics_process(false)
		shot._physics_process(1.0 / fps)
		check(not pellet.is_queued_for_deletion(), "yellow shot misses outside the actual pellet shape at %d updates/s" % fps)
		if not pellet.is_queued_for_deletion(): pellet.queue_free()
		if not shot.is_queued_for_deletion(): shot.queue_free()
		await get_tree().process_frame
		var moving: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
		moving.position = Vector2(50, -50)
		moving.velocity = Vector2.ZERO
		moving.shootable = true
		add_child(moving)
		moving.set_physics_process(false)
		shot = SoulProjectile.new()
		shot.velocity = Vector2(100 * fps, 0)
		add_child(shot)
		shot.set_physics_process(false)
		moving.position = Vector2(50, 50)
		shot._physics_process(1.0 / fps)
		check(moving.is_queued_for_deletion(), "yellow shot detects a target crossing its path between updates at %d updates/s" % fps)
		if not moving.is_queued_for_deletion(): moving.queue_free()
		if not shot.is_queued_for_deletion(): shot.queue_free()
		await get_tree().process_frame
		await set_physics_rate(fps)
		moving = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
		moving.position = Vector2(50, -50)
		moving.velocity = Vector2(0, 100 * fps)
		moving.shootable = true
		add_child(moving)
		shot = SoulProjectile.new()
		shot.velocity = Vector2(100 * fps, 0)
		add_child(shot)
		for frame in range(4): await get_tree().physics_frame
		check(not is_instance_valid(moving) or moving.is_queued_for_deletion(), "actual physics update detects crossing targets at %d ticks/s" % fps)
		if is_instance_valid(moving): moving.queue_free()
		if is_instance_valid(shot): shot.queue_free()
		await get_tree().process_frame
		moving = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
		moving.position = Vector2(50, 0)
		moving.velocity = Vector2.ZERO
		moving.shootable = true
		add_child(moving)
		moving.set_physics_process(false)
		shot = SoulProjectile.new()
		shot.velocity = Vector2(100 * fps, 0)
		add_child(shot)
		shot.set_physics_process(false)
		moving.position = Vector2(150, 0)
		shot._physics_process(1.0 / fps)
		check(not moving.is_queued_for_deletion(), "yellow shot does not hit a target moving away at the same speed")
		if not moving.is_queued_for_deletion(): moving.queue_free()
		if not shot.is_queued_for_deletion(): shot.queue_free()
		await get_tree().process_frame
		for target_speed in [1000.0, 12000.0]:
			moving = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
			moving.position = Vector2(50, 0)
			moving.velocity = Vector2.ZERO
			moving.shootable = true
			add_child(moving)
			moving.set_physics_process(false)
			shot = SoulProjectile.new()
			shot.velocity = Vector2.ZERO
			shot.lifetime = 0.005
			add_child(shot)
			shot.set_physics_process(false)
			moving.position.x -= target_speed / fps
			shot._physics_process(1.0 / fps)
			check(moving.is_queued_for_deletion() == (target_speed > 1000.0), "moving target respects remaining shot lifetime at %d updates/s" % fps)
			if not moving.is_queued_for_deletion(): moving.queue_free()
			if not shot.is_queued_for_deletion(): shot.queue_free()
			await get_tree().process_frame


func test_shootable_polygon() -> void:
	var bullet := BattleBullet.new()
	bullet.position = Vector2(50, 0)
	bullet.velocity = Vector2.ZERO
	bullet.shootable = true
	var polygon := CollisionPolygon2D.new()
	polygon.polygon = PackedVector2Array([Vector2(0, 0), Vector2(40, 0), Vector2(40, 10), Vector2(10, 10), Vector2(10, 40), Vector2(0, 40)])
	bullet.add_child(polygon)
	add_child(bullet)
	bullet.set_physics_process(false)
	var shot := SoulProjectile.new()
	shot.position = Vector2(70, 20)
	shot.velocity = Vector2(1800, 0)
	add_child(shot)
	shot.set_physics_process(false)
	shot._physics_process(1.0 / 60.0)
	check(not bullet.is_queued_for_deletion(), "yellow shot misses the empty notch of a concave polygon")
	shot.position = Vector2(0, 20)
	shot.velocity = Vector2(6000, 0)
	shot._physics_process(1.0 / 60.0)
	check(bullet.is_queued_for_deletion(), "yellow shot hits the solid portion of a concave polygon")
	if not bullet.is_queued_for_deletion(): bullet.queue_free()
	if not shot.is_queued_for_deletion(): shot.queue_free()
	await get_tree().process_frame
	bullet = BattleBullet.new()
	bullet.position = Vector2(50, 0)
	bullet.velocity = Vector2.ZERO
	bullet.shootable = true
	polygon = CollisionPolygon2D.new()
	polygon.polygon = PackedVector2Array([Vector2(-4, 20), Vector2(4, 20), Vector2(4, 30), Vector2(-4, 30)])
	bullet.add_child(polygon)
	add_child(bullet)
	bullet.set_physics_process(false)
	shot = SoulProjectile.new()
	shot.velocity = Vector2(6000, 0)
	add_child(shot)
	shot.set_physics_process(false)
	shot._physics_process(1.0 / 60.0)
	check(not bullet.is_queued_for_deletion(), "shot misses the initial polygon")
	polygon.polygon = PackedVector2Array([Vector2(-4, -5), Vector2(4, -5), Vector2(4, 5), Vector2(-4, 5)])
	shot.position = Vector2.ZERO
	shot._physics_process(1.0 / 60.0)
	check(bullet.is_queued_for_deletion(), "yellow shot sees polygon changes after spawning")
	if not bullet.is_queued_for_deletion(): bullet.queue_free()
	if not shot.is_queued_for_deletion(): shot.queue_free()
	await get_tree().process_frame
	bullet = BattleBullet.new()
	bullet.position = Vector2(50, 0)
	bullet.velocity = Vector2.ZERO
	bullet.shootable = true
	polygon = CollisionPolygon2D.new()
	polygon.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	polygon.polygon = PackedVector2Array([Vector2(0, -20), Vector2(0, 20)])
	bullet.add_child(polygon)
	add_child(bullet)
	bullet.set_physics_process(false)
	shot = SoulProjectile.new()
	shot.velocity = Vector2(6000, 0)
	add_child(shot)
	shot.set_physics_process(false)
	shot._physics_process(1.0 / 60.0)
	check(bullet.is_queued_for_deletion(), "yellow shot hits a polygon built from segments")
	if not bullet.is_queued_for_deletion(): bullet.queue_free()
	if not shot.is_queued_for_deletion(): shot.queue_free()
	await get_tree().process_frame


func test_graze() -> void:
	for fps in [30, 60, 144]:
		await set_physics_rate(fps)
		Global.player_set_hp(20)
		var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
		soul.arena = Rect2(-1000, -1000, 2000, 2000)
		soul.movement_enabled = true
		soul.graze_enabled = true
		add_child(soul)
		var count := [0]
		soul.grazed.connect(func(_bullet): count[0] += 1)
		var bullet: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
		bullet.position = Vector2(15, 0)
		bullet.velocity = Vector2.ZERO
		bullet.destroy_on_contact = false
		add_child(bullet)
		for frame in range(fps + 1): await get_tree().physics_frame
		check(count[0] >= 5 and count[0] <= 7 and Global.player_data.hp == 20, "nearby bullet grants grazes at a time-based cadence at %d ticks/s (count=%d)" % [fps, count[0]])
		var previous: int = count[0]
		soul.invulnerability_remaining = 2.0
		for frame in range(fps / 4): await get_tree().physics_frame
		check(count[0] == previous, "invulnerability suppresses grazing")
		soul.graze_enabled = false
		soul.invulnerability_remaining = 0.0
		for frame in range(fps / 4): await get_tree().physics_frame
		check(count[0] == previous, "disabled graze sensor grants no TP")
		soul.queue_free()
		bullet.queue_free()
		await get_tree().process_frame
	await set_physics_rate(60)
	Global.player_set_hp(20)
	var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
	soul.arena = Rect2(-1000, -1000, 2000, 2000)
	soul.movement_enabled = true
	soul.graze_enabled = true
	add_child(soul)
	var contact_grazes := [0]
	soul.grazed.connect(func(_bullet): contact_grazes[0] += 1)
	var bullet: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
	bullet.velocity = Vector2.ZERO
	bullet.destroy_on_contact = false
	add_child(bullet)
	for frame in range(10): await get_tree().physics_frame
	check(contact_grazes[0] == 0 and Global.player_data.hp == 17, "a direct hit does not count as a graze")
	soul.queue_free()
	bullet.queue_free()
	await get_tree().process_frame


func test_targeted_pellet() -> void:
	for fps in [30, 60, 144]:
		var pellet := TargetedPellet.new()
		pellet.rest_position = Vector2(90, 0)
		pellet.approach_duration = 1.0
		pellet.hold_duration = 0.5
		pellet.launch_velocity = Vector2(0, 120)
		pellet.lifetime = 5.0
		add_child(pellet)
		pellet.set_physics_process(false)
		for frame in range(fps): pellet._physics_process(1.0 / fps)
		check(pellet.position.distance_to(Vector2(90, 0)) < 0.01, "targeted pellet reaches its rest point after one second at %d updates/s" % fps)
		for frame in range(fps / 2): pellet._physics_process(1.0 / fps)
		check(pellet.position.distance_to(Vector2(90, 0)) < 0.01, "targeted pellet waits before launch at %d updates/s" % fps)
		for frame in range(fps / 2): pellet._physics_process(1.0 / fps)
		check(pellet.position.distance_to(Vector2(90, 60)) < 0.02, "targeted pellet launches at the configured speed at %d updates/s" % fps)
		pellet.queue_free()
		await get_tree().process_frame
	var pellet := TargetedPellet.new()
	pellet.rest_position = Vector2(90, 0)
	pellet.approach_duration = 0.2
	pellet.hold_duration = 0.3
	pellet.launch_velocity = Vector2(0, 100)
	pellet.lifetime = 2.0
	add_child(pellet)
	pellet.set_physics_process(false)
	pellet._physics_process(0.6)
	check(pellet.position.distance_to(Vector2(90, 10)) < 0.01, "a long update crosses both pellet phase boundaries")
	pellet.queue_free()
	await get_tree().process_frame
	for test in [{"position": Vector2(45, 0), "hp": 17}, {"position": Vector2(45, 20), "hp": 20}]:
		Global.player_set_hp(20)
		var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
		soul.arena = Rect2(-1000, -1000, 2000, 2000)
		soul.movement_enabled = true
		soul.position = test.position
		add_child(soul)
		await get_tree().physics_frame
		pellet = TargetedPellet.new()
		pellet.rest_position = Vector2(90, 0)
		pellet.approach_duration = 0.2
		pellet.hold_duration = 0.3
		pellet.launch_velocity = Vector2(0, 400)
		pellet.lifetime = 2.0
		add_child(pellet)
		pellet.set_physics_process(false)
		pellet._physics_process(0.6)
		check(Global.player_data.hp == test.hp, "pellet sweeps the actual two-segment path (soul=%s)" % test.position)
		soul.queue_free()
		if is_instance_valid(pellet): pellet.queue_free()
		await get_tree().process_frame


func test_pellet_parallel_and_recoil() -> void:
	for fps in [30, 60, 144]:
		var pellet := TargetedPellet.new()
		pellet.rest_position = Vector2(90, 0)
		pellet.approach_duration = 1.0
		pellet.hold_duration = 0.25
		pellet.launch_timing = TargetedPellet.LaunchTiming.FROM_SPAWN
		pellet.launch_velocity = Vector2(0, 100)
		pellet.lifetime = 5.0
		add_child(pellet)
		pellet.set_physics_process(false)
		for frame in range(fps / 2): pellet._physics_process(1.0 / fps)
		check(pellet.position.distance_to(Vector2(45, 25)) < 0.03, "pellet approach and launch timer run concurrently at %d updates/s" % fps)
		for frame in range(fps / 2): pellet._physics_process(1.0 / fps)
		check(pellet.position.distance_to(Vector2(90, 75)) < 0.03, "concurrent pellet reaches the expected position at %d updates/s" % fps)
		pellet.queue_free()
		await get_tree().process_frame
		pellet = TargetedPellet.new()
		pellet.approach_duration = 0.0
		pellet.hold_duration = 0.5
		pellet.recoil_distance = 12.0
		pellet.recoil_duration = 0.2
		pellet.launch_velocity = Vector2(120, 0)
		pellet.lifetime = 5.0
		add_child(pellet)
		pellet.set_physics_process(false)
		for frame in range(roundi(fps * 0.7)): pellet._physics_process(1.0 / fps)
		var elapsed: float = float(roundi(fps * 0.7)) / float(fps)
		var expected_x := -12.0 + 120.0 * maxf(0.0, elapsed - 0.7)
		check(absf(pellet.position.x - expected_x) < 0.08, "pellet recoils before launching at %d updates/s" % fps)
		pellet.queue_free()
		await get_tree().process_frame
	var back := TargetedPellet.new()
	back.rest_position = Vector2(100, 0)
	back.approach_duration = 1.0
	back.hold_duration = 2.0
	back.approach_ease = TargetedPellet.ApproachEase.BACK_OUT
	add_child(back)
	back.set_physics_process(false)
	back._physics_process(0.6)
	check(back.position.x > 100.0, "back-out approach overshoots its rest point")
	back._physics_process(0.4)
	check(back.position.distance_to(Vector2(100, 0)) < 0.01, "back-out approach settles at its rest point")
	back.queue_free()
	await get_tree().process_frame


func test_bone_cone() -> void:
	var turning_positions: Array[Vector2] = []
	for fps in [30, 60, 144]:
		var cone := BoneCone.new()
		cone.target_angle = PI / 2.0
		cone.turn_speed = PI
		cone.charge_duration = 0.5
		cone.acceleration = 120.0
		cone.lifetime = 5.0
		add_child(cone)
		cone.set_physics_process(false)
		for frame in range(fps * 2): cone._physics_process(1.0 / fps)
		check(cone.position.distance_to(Vector2(0, 135)) < 0.05 and absf(cone.speed - 180.0) < 0.01, "bone cone charges, turns and accelerates at %d updates/s" % fps)
		cone.queue_free()
		await get_tree().process_frame
		cone = BoneCone.new()
		cone.target_angle = PI / 2.0
		cone.turn_speed = PI
		cone.charge_duration = 0.0
		cone.acceleration = 100.0
		cone.lifetime = 5.0
		add_child(cone)
		cone.set_physics_process(false)
		for frame in range(fps): cone._physics_process(1.0 / fps)
		turning_positions.append(cone.position)
		cone.queue_free()
		await get_tree().process_frame
	check(turning_positions[0].distance_to(turning_positions[2]) < 0.05 and turning_positions[1].distance_to(turning_positions[2]) < 0.05, "turning and accelerating cone follows the same trajectory at different update rates")
	for fps in [30, 60, 144]:
		await set_physics_rate(fps)
		Global.player_set_hp(20)
		var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
		soul.position = Vector2(0, 100)
		soul.arena = Rect2(-1000, -1000, 2000, 2000)
		soul.movement_enabled = true
		add_child(soul)
		await get_tree().physics_frame
		var cone := BoneCone.new()
		cone.rotation = PI / 2.0
		cone.target_angle = PI / 2.0
		cone.charge_duration = 0.0
		cone.speed = 12000.0
		cone.acceleration = 0.0
		add_child(cone)
		for frame in range(6): await get_tree().physics_frame
		check(Global.player_data.hp == 17, "fast bone cone hits soul at %d physics ticks/s" % fps)
		soul.queue_free()
		if is_instance_valid(cone): cone.queue_free()
		await get_tree().process_frame


func test_gun_shot() -> void:
	for fps in [30, 60, 144]:
		await set_physics_rate(fps)
		Global.player_set_hp(20)
		var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
		soul.arena = Rect2(-1000, -1000, 2000, 2000)
		soul.movement_enabled = true
		add_child(soul)
		await get_tree().physics_frame
		var gun := GunShot.new()
		gun.fade_in = 0.001
		gun.aim_duration = 0.0
		gun.fire_duration = 0.001
		gun.fade_out = 0.5
		var shots := [0]
		gun.fired.connect(func(): shots[0] += 1)
		add_child(gun)
		for frame in range(4): await get_tree().physics_frame
		check(Global.player_data.hp == 17 and shots[0] == 1, "short gun firing window hits once at %d ticks/s" % fps)
		soul.queue_free()
		await get_tree().process_frame
		Global.player_set_hp(20)
		var late_soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
		late_soul.arena = Rect2(-1000, -1000, 2000, 2000)
		late_soul.movement_enabled = true
		add_child(late_soul)
		for frame in range(4): await get_tree().physics_frame
		check(Global.player_data.hp == 20, "gun cannot hit during fade-out at %d ticks/s" % fps)
		late_soul.queue_free()
		if is_instance_valid(gun): gun.queue_free()
		await get_tree().process_frame
	await set_physics_rate(60)
	Global.player_set_hp(20)
	var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
	soul.arena = Rect2(-1000, -1000, 2000, 2000)
	soul.movement_enabled = true
	add_child(soul)
	var gun := GunShot.new()
	gun.fade_in = 0.3
	gun.aim_duration = 0.3
	add_child(gun)
	for frame in range(10): await get_tree().physics_frame
	check(Global.player_data.hp == 20, "gun aiming marker is harmless before firing")
	soul.queue_free()
	gun.queue_free()
	await get_tree().process_frame


func test_platform_carry() -> void:
	await set_physics_rate(60)
	var platform := BattlePlatform.new()
	platform.position = Vector2(0, 0)
	platform.platform_width = 100
	platform.velocity = Vector2(40, 0)
	platform.lifetime = 10
	add_child(platform)
	var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
	soul.position = Vector2(0, -30)
	soul.arena = Rect2(-500, -500, 1000, 1000)
	soul.movement_enabled = true
	add_child(soul)
	soul.set_mode("blue")
	for frame in range(35): await get_tree().physics_frame
	var before := soul.global_position.x
	for frame in range(30): await get_tree().physics_frame
	check(soul.is_on_floor(), "blue soul stays on a moving platform")
	check(soul.global_position.x - before > 12.0, "moving platform carries a blue soul (moved %.2f)" % (soul.global_position.x - before))
	platform.queue_free()
	soul.queue_free()
	await get_tree().process_frame


func jump_peak(held_frames: int) -> float:
	var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
	soul.arena = Rect2(-100, -200, 200, 200)
	soul.position = Vector2(0, -8)
	soul.movement_enabled = true
	add_child(soul)
	soul.set_mode("blue")
	await get_tree().physics_frame
	Input.action_press("ui_up")
	var min_y := soul.position.y
	for frame in range(55):
		await get_tree().physics_frame
		if frame == held_frames: Input.action_release("ui_up")
		min_y = minf(min_y, soul.position.y)
	Input.action_release("ui_up")
	soul.queue_free()
	await get_tree().process_frame
	return min_y


func test_jump_release() -> void:
	await set_physics_rate(60)
	var short_peak := await jump_peak(3)
	var held_peak := await jump_peak(30)
	check(short_peak - held_peak > 10.0, "releasing jump early reduces its height (short=%.2f held=%.2f)" % [short_peak, held_peak])


func test_gravity_directions() -> void:
	await set_physics_rate(60)
	for direction in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
		soul.arena = Rect2(-100, -100, 200, 200)
		soul.position = direction * 92.0
		soul.gravity_direction = direction
		soul.movement_enabled = true
		add_child(soul)
		soul.set_mode("blue")
		for frame in range(3): await get_tree().physics_frame
		var start := soul.position
		var jump := soul._jump_action(direction)
		Input.action_press(jump)
		for frame in range(4): await get_tree().physics_frame
		Input.action_release(jump)
		check((soul.position - start).dot(direction) < -5.0, "blue soul jumps against gravity %s" % direction)
		soul.queue_free()
		await get_tree().process_frame


func test_ceiling_collision() -> void:
	await set_physics_rate(60)
	var wall := StaticBody2D.new()
	wall.position = Vector2(0, -45)
	var hitbox := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(200, 5)
	hitbox.shape = rectangle
	wall.add_child(hitbox)
	add_child(wall)
	var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
	soul.arena = Rect2(-100, -200, 200, 200)
	soul.position = Vector2(0, -8)
	soul.movement_enabled = true
	add_child(soul)
	soul.set_mode("blue")
	await get_tree().physics_frame
	Input.action_press("ui_up")
	var stuck := false
	for frame in range(18):
		await get_tree().physics_frame
		if soul.is_on_ceiling() and soul.gravity_speed < -1.0: stuck = true
	Input.action_release("ui_up")
	check(not stuck, "blue soul cancels upward speed after hitting the ceiling")
	wall.queue_free()
	soul.queue_free()
	await get_tree().process_frame
