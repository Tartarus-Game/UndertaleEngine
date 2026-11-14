extends "res://tests/test_runner.gd"

class MovingCarrier extends Node2D:
	var velocity := Vector2.ZERO

	func _physics_process(delta: float) -> void:
		position += velocity * delta


class RotatingPulseCarrier extends Node2D:
	var angular_velocity := 0.0

	func _physics_process(delta: float) -> void:
		rotation += angular_velocity * delta


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
	await test_parent_driven_bullets()
	await test_parent_motion_physics()
	await test_relative_soul_motion()
	await test_parent_driven_soul_motion()
	await test_spawn_frame_soul_motion()
	await test_new_bullet_initial_overlap()
	await test_disabled_bullet_monitoring()
	await test_bullet_lifetime()
	await test_repeated_fast_contact()
	await test_fast_pulse()
	await test_pulse_relative_motion()
	await test_pulse_reentry_karma()
	await test_pulse_spawn_after_soul_moves()
	await test_pulse_orbital_motion()
	await test_pellet_warning()
	await test_short_beams()
	await test_soul_projectile_order_and_lifetime()
	await test_soul_projectile_target_shapes()
	await test_soul_projectile_shootable_toggle()
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
	await test_contact_on_expiration_tick()
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


func test_parent_driven_bullets() -> void:
	for fps in [30, 60, 144]:
		await set_physics_rate(fps)
		for case in [
			{"y": 0.0, "own_motion": 0.0, "lifetime": 1.0, "expected": 17, "label": "crossing"},
			{"y": 60.0, "own_motion": 0.0, "lifetime": 1.0, "expected": 20, "label": "near miss"},
			{"y": 0.0, "own_motion": -150.0, "lifetime": 1.0, "expected": 20, "label": "opposing motion"},
			{"y": 0.0, "own_motion": 0.0, "lifetime": 0.25 / fps, "expected": 20, "label": "expires before crossing"},
			{"y": 0.0, "own_motion": 0.0, "lifetime": 0.75 / fps, "expected": 17, "label": "crosses before expiry"},
		]:
			Global.player_set_hp(20)
			var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
			soul.movement_enabled = false
			add_child(soul)
			soul.set_physics_process(false)
			var carrier := Node2D.new()
			add_child(carrier)
			var bullet: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
			bullet.position = Vector2(-100.0, case.y)
			bullet.velocity = Vector2(case.own_motion * fps, 0.0)
			carrier.add_child(bullet)
			bullet.set_physics_process(false)
			for frame in range(3): await get_tree().physics_frame
			soul.movement_enabled = true
			bullet.lifetime = case.lifetime
			carrier.position = Vector2(200.0, 0.0)
			bullet._physics_process(1.0 / fps)
			check(Global.player_data.hp == case.expected, "parent-driven bullet: %s at %d ticks/s (HP=%d)" % [case.label, fps, Global.player_data.hp])
			soul.queue_free()
			carrier.queue_free()
			await get_tree().process_frame


func test_pulse_reentry_karma() -> void:
	await set_physics_rate(60)
	Global.player_set_hp(10)
	var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
	add_child(soul)
	soul.set_physics_process(false)
	var pulse := PatternBullet.new()
	pulse.position = Vector2(-100, 0)
	pulse.shape_type = PatternBullet.Shape.PULSE
	pulse.radius = 40.0
	pulse.width = 1.0
	pulse.expansion_speed = 0.0
	pulse.velocity = Vector2.ZERO
	pulse.rule = BattleBullet.Rule.HEAL
	pulse.destroy_on_contact = false
	add_child(pulse)
	pulse.set_physics_process(false)
	for i in range(3): await get_tree().physics_frame
	soul.movement_enabled = true
	pulse.velocity = Vector2(12000, 0)
	pulse._physics_process(1.0 / 60)
	check(Global.player_data.hp == 13, "healing pulse applies on the first crossing")
	pulse.velocity = Vector2(-12000, 0)
	pulse._physics_process(1.0 / 60)
	check(Global.player_data.hp == 16, "healing pulse applies again after leaving and crossing")
	soul.queue_free()
	pulse.queue_free()
	await get_tree().process_frame

	Global.player_set_hp(20)
	Global.player_data.kr = 0.0
	soul = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
	soul.position = Vector2(40, 0)
	add_child(soul)
	soul.set_physics_process(false)
	pulse = PatternBullet.new()
	pulse.shape_type = PatternBullet.Shape.PULSE
	pulse.radius = 40.0
	pulse.width = 1.0
	pulse.expansion_speed = 0.0
	pulse.velocity = Vector2.ZERO
	pulse.karma = true
	pulse.karma_per_second = 120.0
	pulse.destroy_on_contact = false
	add_child(pulse)
	pulse.set_physics_process(false)
	for i in range(3): await get_tree().physics_frame
	soul.movement_enabled = true
	for i in range(3): pulse._physics_process(1.0 / 60)
	check(is_equal_approx(Global.player_data.kr, 9.0), "continuous pulse contact applies KR once per elapsed step (KR=%.2f)" % Global.player_data.kr)
	Global.player_data.kr = 0.0
	soul.queue_free()
	pulse.queue_free()
	await get_tree().process_frame


func test_parent_motion_physics() -> void:
	for fps in [30, 60, 144]:
		await set_physics_rate(fps)
		for case in [
			{"y": 0.0, "motion": 200.0, "lifetime": 1.0, "expected": 17, "label": "crossing"},
			{"y": 60.0, "motion": 200.0, "lifetime": 1.0, "expected": 20, "label": "near miss"},
			{"y": 0.0, "motion": 200.0, "lifetime": 0.25 / fps, "expected": 20, "label": "crossing after expiry"},
			{"y": 0.0, "motion": 200.0, "lifetime": 0.75 / fps, "expected": 17, "label": "crossing before expiry"},
			{"y": 0.0, "motion": 100.0, "lifetime": 0.25 / fps, "expected": 20, "label": "endpoint overlaps after expiry"},
		]:
			Global.player_set_hp(20)
			var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
			soul.movement_enabled = true
			soul.arena = Rect2(-1000, -1000, 2000, 2000)
			add_child(soul)
			var carrier := MovingCarrier.new()
			add_child(carrier)
			var bullet: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
			bullet.position = Vector2(-100, case.y)
			bullet.velocity = Vector2.ZERO
			carrier.add_child(bullet)
			for frame in range(3): await get_tree().physics_frame
			bullet.lifetime = case.lifetime
			carrier.velocity = Vector2(case.motion * fps, 0.0)
			for frame in range(3): await get_tree().physics_frame
			check(Global.player_data.hp == case.expected, "physics-driven parent: %s at %d ticks/s (HP=%d)" % [case.label, fps, Global.player_data.hp])
			soul.queue_free()
			carrier.queue_free()
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


func test_pulse_relative_motion() -> void:
	for fps in [30, 60, 144]:
		await set_physics_rate(fps)
		for test in [
			{"name": "soul crosses a stationary ring", "soul": Vector2(-100, 0), "soul_step": 200.0, "radius": 40.0, "growth": 0.0, "center_step": 0.0, "hp": 17},
			{"name": "parent carries soul across a stationary ring", "soul": Vector2(-100, 0), "soul_step": 0.0, "soul_parent_step": 200.0, "radius": 40.0, "growth": 0.0, "center_step": 0.0, "hp": 17},
			{"name": "very fast soul crosses a narrow ring", "soul": Vector2(-10000123, 0), "soul_step": 20000000.0, "radius": 40.0, "growth": 0.0, "center_step": 0.0, "arena": Rect2(-20000000, -1000, 40000000, 2000), "hp": 17},
			{"name": "tangent reaches the ring", "soul": Vector2(-100, 45), "soul_step": 200.0, "radius": 40.0, "growth": 0.0, "center_step": 0.0, "hp": 17},
			{"name": "near tangent misses the ring", "soul": Vector2(-100, 46), "soul_step": 200.0, "radius": 40.0, "growth": 0.0, "center_step": 0.0, "hp": 20},
			{"name": "soul and expanding ring never meet", "soul": Vector2(5, 0), "soul_step": 55.0, "radius": 20.0, "growth": 80.0, "center_step": 0.0, "hp": 20},
			{"name": "ring center moves across stationary soul", "soul": Vector2(100, 0), "soul_step": 0.0, "radius": 40.0, "growth": 0.0, "center_step": 200.0, "hp": 17},
			{"name": "ring and soul move together without meeting", "soul": Vector2(100, 0), "soul_step": 200.0, "radius": 40.0, "growth": 0.0, "center_step": 200.0, "hp": 20},
			{"name": "crossing after expiration", "soul": Vector2(-100, 0), "soul_step": 200.0, "radius": 40.0, "growth": 0.0, "center_step": 0.0, "lifetime": 0.2, "hp": 20},
			{"name": "crossing before expiration", "soul": Vector2(-100, 0), "soul_step": 200.0, "radius": 40.0, "growth": 0.0, "center_step": 0.0, "lifetime": 0.4, "hp": 17},
			{"name": "crossing while warned", "soul": Vector2(-100, 0), "soul_step": 200.0, "radius": 40.0, "growth": 0.0, "center_step": 0.0, "warning": 0.9, "hp": 20},
			{"name": "second crossing after warning", "soul": Vector2(-100, 0), "soul_step": 200.0, "radius": 40.0, "growth": 0.0, "center_step": 0.0, "warning": 0.6, "hp": 17},
			{"name": "shield blocks ring approaching from the front", "soul": Vector2(-100, 0), "soul_step": 200.0, "radius": 40.0, "growth": 0.0, "center_step": 0.0, "mode": "green+red", "hp": 20},
			{"name": "shield does not block ring approaching from behind", "soul": Vector2(100, 0), "soul_step": 0.0, "radius": 40.0, "growth": 0.0, "center_step": 200.0, "mode": "green+red", "hp": 17},
			{"name": "scaled ring reaches outside its unscaled radius", "soul": Vector2(75, 0), "soul_step": 0.0, "radius": 40.0, "growth": 0.0, "center_step": 0.0, "scale": 2.0, "hp": 17},
			{"name": "disabled collision mask ignores crossing", "soul": Vector2(-100, 0), "soul_step": 200.0, "radius": 40.0, "growth": 0.0, "center_step": 0.0, "mask": 0, "hp": 20},
			{"name": "unmonitorable hurtbox ignores crossing", "soul": Vector2(-100, 0), "soul_step": 200.0, "radius": 40.0, "growth": 0.0, "center_step": 0.0, "disable_hurtbox": true, "hp": 20},
			{"name": "disabled pulse shape ignores crossing", "soul": Vector2(-100, 0), "soul_step": 200.0, "radius": 40.0, "growth": 0.0, "center_step": 0.0, "disable_shape": true, "hp": 20},
		]:
			Global.player_set_hp(20)
			var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
			soul.position = test.soul
			soul.speed = float(test.soul_step) * fps
			soul.arena = test.get("arena", Rect2(-1000, -1000, 2000, 2000))
			var soul_parent := MovingCarrier.new()
			add_child(soul_parent)
			soul_parent.add_child(soul)
			var carrier := MovingCarrier.new()
			carrier.scale = Vector2.ONE * float(test.get("scale", 1.0))
			add_child(carrier)
			var pulse := PatternBullet.new()
			pulse.shape_type = PatternBullet.Shape.PULSE
			pulse.radius = test.radius
			pulse.width = 1.0
			pulse.velocity = Vector2.ZERO
			pulse.expansion_speed = test.growth * fps
			pulse.warning = float(test.get("warning", 0.0)) / fps
			pulse.destroy_on_contact = false
			carrier.add_child(pulse)
			if test.has("mask"): pulse.collision_mask = test.mask
			if test.has("disable_hurtbox"): soul.get_node("HurtBox").monitorable = false
			if test.has("disable_shape"): (pulse.get_child(0) as CollisionShape2D).disabled = true
			if test.has("mode"): soul.set_mode(test.mode)
			soul.set_physics_process(false)
			pulse.set_physics_process(false)
			for i in range(3): await get_tree().physics_frame
			soul.movement_enabled = true
			pulse.lifetime = float(test.get("lifetime", 2.0)) / fps
			carrier.velocity = Vector2(test.center_step * fps, 0)
			soul_parent.velocity = Vector2(float(test.get("soul_parent_step", 0.0)) * fps, 0)
			Input.action_press("ui_right")
			soul.set_physics_process(true)
			pulse.set_physics_process(true)
			await get_tree().physics_frame
			await get_tree().physics_frame
			soul.set_physics_process(false)
			if is_instance_valid(pulse): pulse.set_physics_process(false)
			carrier.set_physics_process(false)
			soul_parent.set_physics_process(false)
			Input.action_release("ui_right")
			check(Global.player_data.hp == test.hp, "pulse %s at %d Hz (HP=%d)" % [test.name, fps, Global.player_data.hp])
			soul_parent.queue_free()
			carrier.queue_free()
			await get_tree().process_frame


func test_pulse_spawn_after_soul_moves() -> void:
	await set_physics_rate(60)
	Global.player_set_hp(20)
	var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
	soul.position = Vector2(-100, 0)
	soul.speed = 12000.0
	soul.arena = Rect2(-1000, -1000, 2000, 2000)
	soul.movement_enabled = true
	add_child(soul)
	soul.set_physics_process(false)
	await get_tree().physics_frame
	Input.action_press("ui_right")
	soul._physics_process(1.0 / 60)
	Input.action_release("ui_right")
	var pulse := PatternBullet.new()
	pulse.shape_type = PatternBullet.Shape.PULSE
	pulse.radius = 40.0
	pulse.width = 1.0
	pulse.expansion_speed = 0.0
	pulse.velocity = Vector2.ZERO
	pulse.destroy_on_contact = false
	add_child(pulse)
	pulse.set_physics_process(false)
	pulse._physics_process(1.0 / 60)
	check(Global.player_data.hp == 20, "pulse ignores soul movement before pulse was spawned")
	soul.queue_free()
	pulse.queue_free()
	await get_tree().process_frame


func test_pulse_orbital_motion() -> void:
	for fps in [30, 60, 144]:
		await set_physics_rate(fps)
		for test in [
			{"name": "arc crosses soul", "soul": Vector2(70.71, 70.71), "hp": 17},
			{"name": "arc misses soul on chord", "soul": Vector2(50, 50), "hp": 20},
			{"name": "arc crosses while warned", "soul": Vector2(70.71, 70.71), "warning": 0.9, "hp": 20},
			{"name": "arc crosses after warning", "soul": Vector2(70.71, 70.71), "warning": 0.2, "hp": 17},
		]:
			Global.player_set_hp(20)
			var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
			soul.position = test.soul
			soul.movement_enabled = true
			add_child(soul)
			var carrier := RotatingPulseCarrier.new()
			add_child(carrier)
			var pulse := PatternBullet.new()
			pulse.shape_type = PatternBullet.Shape.PULSE
			pulse.position = Vector2(100, 0)
			pulse.radius = 10.0
			pulse.width = 1.0
			pulse.velocity = Vector2.ZERO
			pulse.expansion_speed = 0.0
			pulse.warning = float(test.get("warning", 0.0)) / fps
			pulse.destroy_on_contact = false
			carrier.add_child(pulse)
			pulse.set_physics_process(false)
			for i in range(3): await get_tree().physics_frame
			pulse.lifetime = 1.0 / fps
			carrier.angular_velocity = PI * 0.5 * fps
			pulse.set_physics_process(true)
			await get_tree().physics_frame
			await get_tree().physics_frame
			carrier.set_physics_process(false)
			check(Global.player_data.hp == test.hp, "orbital pulse %s at %d Hz (HP=%d)" % [test.name, fps, Global.player_data.hp])
			soul.queue_free()
			carrier.queue_free()
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


func test_soul_projectile_shootable_toggle() -> void:
	for observe_disabled in [false, true]:
		var target: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
		target.position = Vector2(50, 0)
		target.velocity = Vector2.ZERO
		target.shootable = true
		add_child(target)
		target.set_physics_process(false)
		var shot := SoulProjectile.new()
		shot.velocity = Vector2.ZERO
		add_child(shot)
		shot.set_physics_process(false)
		shot._physics_process(1.0 / 60.0)
		target.shootable = false
		target.position = Vector2(-50, 0)
		if observe_disabled: shot._physics_process(1.0 / 60.0)
		target.shootable = true
		shot._physics_process(1.0 / 60.0)
		check(not target.is_queued_for_deletion() and not shot.is_queued_for_deletion(), "reactivating a target ignores motion while disabled (observed=%s)" % observe_disabled)
		if not shot.is_queued_for_deletion():
			target.position = Vector2(50, 0)
			target.shootable = true # Reassigning the same value must not discard motion.
			shot._physics_process(1.0 / 60.0)
			check(target.is_queued_for_deletion(), "reactivated targets still detect subsequent motion")
		if not target.is_queued_for_deletion(): target.queue_free()
		if not shot.is_queued_for_deletion(): shot.queue_free()
		await get_tree().process_frame
	var target: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
	target.position = Vector2(50, 0)
	target.velocity = Vector2.ZERO
	target.shootable = true
	add_child(target)
	target.set_physics_process(false)
	var shot := SoulProjectile.new()
	shot.velocity = Vector2.ZERO
	add_child(shot)
	shot.set_physics_process(false)
	target.shootable = false
	target.position = Vector2(-50, 0)
	target.shootable = true
	target.position = Vector2(50, 0)
	shot._physics_process(1.0 / 60.0)
	check(target.is_queued_for_deletion(), "motion after reactivation is detected in the same update")
	if not target.is_queued_for_deletion(): target.queue_free()
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


func test_contact_on_expiration_tick() -> void:
	for fps in [30, 60, 144]:
		await set_physics_rate(fps)
		for mode in ["damage", "karma", "expired"]:
			Global.player_set_hp(20)
			Global.player_data.kr = 0.0
			var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
			soul.movement_enabled = false
			add_child(soul)
			soul.set_physics_process(false)
			var bullet: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
			bullet.velocity = Vector2.ZERO
			bullet.destroy_on_contact = false
			add_child(bullet)
			bullet.set_physics_process(false)
			for frame in range(4): await get_tree().physics_frame
			var hurtbox := soul.get_node("HurtBox") as Area2D
			check(bullet.get_overlapping_areas().has(hurtbox), "bullet and soul overlap before the expiration test")
			soul.movement_enabled = true
			bullet.lifetime = 0.0 if mode == "expired" else 0.5 / fps
			if mode == "karma":
				bullet.karma = true
				bullet.karma_per_second = 4.0 * fps
				bullet._contact_ticks[hurtbox.get_instance_id()] = 0.0
			bullet._physics_process(1.0 / fps)
			var expected_hp := 17 if mode == "damage" else 20
			var expected_kr := 2.0 if mode == "karma" else 0.0
			check(Global.player_data.hp == expected_hp and is_equal_approx(Global.player_data.kr, expected_kr),
				"expiration tick applies %s only during the remaining lifetime at %d ticks/s (HP=%d, KR=%.2f)" % [mode, fps, Global.player_data.hp, Global.player_data.kr])
			check(bullet.is_queued_for_deletion(), "bullet expires at the end of its lifetime")
			soul.queue_free()
			if not bullet.is_queued_for_deletion(): bullet.queue_free()
			await get_tree().process_frame


func test_relative_soul_motion() -> void:
	for fps in [30, 60, 144]:
		await set_physics_rate(fps)
		for test in [
			{"name": "soul crosses stationary bullet", "soul": Vector2(-100, 0), "bullet": Vector2.ZERO, "action": "ui_right", "bullet_motion": Vector2.ZERO, "hp": 17},
			{"name": "opposite paths cross", "soul": Vector2(100, 0), "bullet": Vector2(-100, 0), "action": "ui_left", "bullet_motion": Vector2(200, 0), "hp": 17},
			{"name": "same speed follows without meeting", "soul": Vector2.ZERO, "bullet": Vector2(-100, 0), "action": "ui_right", "bullet_motion": Vector2(200, 0), "hp": 20},
			{"name": "paths intersect at different times", "soul": Vector2(0, -200), "bullet": Vector2(-100, 0), "action": "ui_down", "bullet_motion": Vector2(200, 0), "hp": 20},
			{"name": "crossing after expiration", "soul": Vector2(-100, 0), "bullet": Vector2.ZERO, "action": "ui_right", "bullet_motion": Vector2.ZERO, "lifetime": 0.3, "hp": 20},
			{"name": "crossing before expiration", "soul": Vector2(-100, 0), "bullet": Vector2.ZERO, "action": "ui_right", "bullet_motion": Vector2.ZERO, "lifetime": 0.7, "hp": 17},
			{"name": "initial overlap moving together before expiration", "soul": Vector2.ZERO, "bullet": Vector2.ZERO, "action": "ui_right", "bullet_motion": Vector2(200, 0), "lifetime": 0.5, "hp": 17},
			{"name": "blue hits moving soul", "soul": Vector2(-100, 0), "bullet": Vector2.ZERO, "action": "ui_right", "bullet_motion": Vector2.ZERO, "rule": BattleBullet.Rule.BLUE, "hp": 17},
			{"name": "orange spares moving soul", "soul": Vector2(-100, 0), "bullet": Vector2.ZERO, "action": "ui_right", "bullet_motion": Vector2.ZERO, "rule": BattleBullet.Rule.ORANGE, "hp": 20},
			{"name": "shield faces incoming bullet at impact", "soul": Vector2(-100, 0), "bullet": Vector2(100, 0), "action": "ui_right", "bullet_motion": Vector2(-200, 0), "mode": "green+red", "hp": 20},
			{"name": "shield does not face bullet arriving from behind", "soul": Vector2.ZERO, "bullet": Vector2(-100, 0), "action": "ui_right", "bullet_motion": Vector2(400, 0), "mode": "green+red", "hp": 17},
			{"name": "tiny shapes cross below the old distance threshold", "soul": Vector2(-1, 0), "bullet": Vector2.ZERO, "action": "ui_right", "soul_distance": 2.0, "bullet_motion": Vector2.ZERO, "tiny": true, "hp": 17},
			{"name": "disabled collision mask ignores sweep", "soul": Vector2(-100, 0), "bullet": Vector2.ZERO, "action": "ui_right", "bullet_motion": Vector2.ZERO, "mask": 0, "hp": 20},
			{"name": "unmonitorable hurtbox ignores sweep", "soul": Vector2(-100, 0), "bullet": Vector2.ZERO, "action": "ui_right", "bullet_motion": Vector2.ZERO, "disabled_hurtbox": true, "hp": 20},
			{"name": "arena clamp stops before a distant bullet", "soul": Vector2(-80, 0), "bullet": Vector2(80, 0), "action": "ui_right", "bullet_motion": Vector2.ZERO, "arena": Rect2(-100, -100, 120, 200), "hp": 20},
			{"name": "arena clamp preserves earlier crossings", "soul": Vector2(-80, 0), "bullet": Vector2.ZERO, "action": "ui_right", "bullet_motion": Vector2.ZERO, "arena": Rect2(-100, -100, 120, 200), "hp": 17},
			{"name": "explicit compatible priorities are preserved", "soul": Vector2(-100, 0), "bullet": Vector2.ZERO, "action": "ui_right", "bullet_motion": Vector2.ZERO, "priorities": true, "hp": 17},
			{"name": "crossing before warning ends is harmless", "soul": Vector2(-100, 0), "bullet": Vector2.ZERO, "action": "ui_right", "bullet_motion": Vector2.ZERO, "warning": 0.75, "hp": 20},
			{"name": "leaving initial overlap before warning ends is harmless", "soul": Vector2.ZERO, "bullet": Vector2.ZERO, "action": "ui_right", "bullet_motion": Vector2.ZERO, "warning": 0.75, "hp": 20},
			{"name": "crossing after warning ends hits", "soul": Vector2(-100, 0), "bullet": Vector2.ZERO, "action": "ui_right", "bullet_motion": Vector2.ZERO, "warning": 0.25, "hp": 17},
			{"name": "warning bullet remains harmless", "soul": Vector2(-100, 0), "bullet": Vector2.ZERO, "action": "ui_right", "bullet_motion": Vector2.ZERO, "warning": 3.0, "hp": 20},
		]:
			for soul_first in [true, false]:
				Global.player_set_hp(20)
				var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
				soul.position = test.soul
				soul.speed = float(test.get("soul_distance", 200.0)) * fps
				soul.arena = test.get("arena", Rect2(-1000, -1000, 2000, 2000))
				var bullet: BattleBullet
				if test.has("warning"):
					var warning_bullet := PatternBullet.new()
					warning_bullet.warning = float(test.warning) / fps
					bullet = warning_bullet
				else:
					bullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
				bullet.position = test.bullet
				bullet.velocity = Vector2.ZERO
				bullet.destroy_on_contact = false
				bullet.rule = test.get("rule", BattleBullet.Rule.WHITE)
				if test.has("priorities"):
					soul.process_physics_priority = 10
					bullet.process_physics_priority = 40
				if test.has("mask"): bullet.collision_mask = test.mask
				if test.has("tiny"):
					var tiny_circle := CircleShape2D.new()
					tiny_circle.radius = 0.1
					bullet.get_node("CollisionShape2D").shape = tiny_circle
					var tiny_box := soul.get_node("HurtBox/HitBox") as CollisionPolygon2D
					tiny_box.polygon = PackedVector2Array([Vector2(-0.1, -0.1), Vector2(-0.1, 0.1), Vector2(0.1, 0.1), Vector2(0.1, -0.1)])
				if test.has("disabled_hurtbox"): soul.get_node("HurtBox").monitorable = false
				if soul_first:
					add_child(soul)
					add_child(bullet)
				else:
					add_child(bullet)
					add_child(soul)
				if test.has("mode"): soul.set_mode(test.mode)
				if test.has("priorities"): check(soul.process_physics_priority == 10 and bullet.process_physics_priority == 40, "explicit physics priorities remain unchanged")
				soul.set_physics_process(false)
				bullet.set_physics_process(false)
				for i in range(3): await get_tree().physics_frame
				soul.movement_enabled = true
				bullet.velocity = test.bullet_motion * fps
				bullet.lifetime = float(test.get("lifetime", 2.0)) / fps
				Input.action_press(test.action)
				soul.set_physics_process(true)
				bullet.set_physics_process(true)
				await get_tree().physics_frame
				await get_tree().physics_frame
				soul.set_physics_process(false)
				if is_instance_valid(bullet): bullet.set_physics_process(false)
				Input.action_release(test.action)
				check(Global.player_data.hp == test.hp, "%s at %d Hz (soul first=%s, hp=%d)" % [test.name, fps, soul_first, Global.player_data.hp])
				soul.queue_free()
				if is_instance_valid(bullet) and not bullet.is_queued_for_deletion(): bullet.queue_free()
				await get_tree().process_frame


func test_new_bullet_initial_overlap() -> void:
	for fps in [30, 60, 144]:
		await set_physics_rate(fps)
		Global.player_set_hp(20)
		var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
		soul.movement_enabled = true
		add_child(soul)
		soul.set_physics_process(false)
		await get_tree().physics_frame
		var bullet: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
		bullet.lifetime = 0.5 / fps
		bullet.velocity = Vector2.ZERO
		bullet.destroy_on_contact = false
		add_child(bullet)
		bullet.set_physics_process(false)
		# Exercise the first update before the server has refreshed Area overlaps.
		bullet._physics_process(1.0 / fps)
		check(Global.player_data.hp == 17, "new short-lived bullet hits an initial overlap before Area signals at %d Hz" % fps)
		soul.queue_free()
		if is_instance_valid(bullet) and not bullet.is_queued_for_deletion(): bullet.queue_free()
		await get_tree().process_frame


func test_parent_driven_soul_motion() -> void:
	for fps in [30, 60, 144]:
		await set_physics_rate(fps)
		for test in [
			{"name": "stationary bullet crossing", "soul": Vector2(-100, 0), "bullet": Vector2.ZERO, "soul_move": Vector2(200, 0), "bullet_move": Vector2.ZERO, "expected": 17},
			{"name": "near miss", "soul": Vector2(-100, 60), "bullet": Vector2.ZERO, "soul_move": Vector2(200, 0), "bullet_move": Vector2.ZERO, "expected": 20},
			{"name": "opposing bullet", "soul": Vector2(-100, 0), "bullet": Vector2(100, 0), "soul_move": Vector2(200, 0), "bullet_move": Vector2(-200, 0), "expected": 17},
			{"name": "same speed separation", "soul": Vector2(-100, 0), "bullet": Vector2(-200, 0), "soul_move": Vector2(200, 0), "bullet_move": Vector2(200, 0), "expected": 20},
			{"name": "expires before crossing", "soul": Vector2(-100, 0), "bullet": Vector2.ZERO, "soul_move": Vector2(200, 0), "bullet_move": Vector2.ZERO, "lifetime": 0.25, "expected": 20},
			{"name": "crosses before expiry", "soul": Vector2(-100, 0), "bullet": Vector2.ZERO, "soul_move": Vector2(200, 0), "bullet_move": Vector2.ZERO, "lifetime": 0.75, "expected": 17},
			{"name": "blue detects parent movement", "soul": Vector2(-100, 0), "bullet": Vector2.ZERO, "soul_move": Vector2(200, 0), "bullet_move": Vector2.ZERO, "rule": BattleBullet.Rule.BLUE, "expected": 17},
			{"name": "orange spares parent movement", "soul": Vector2(-100, 0), "bullet": Vector2.ZERO, "soul_move": Vector2(200, 0), "bullet_move": Vector2.ZERO, "rule": BattleBullet.Rule.ORANGE, "expected": 20},
			{"name": "blue detects parent movement when soul processing is disabled", "soul": Vector2(-100, 0), "bullet": Vector2.ZERO, "soul_move": Vector2(200, 0), "bullet_move": Vector2.ZERO, "rule": BattleBullet.Rule.BLUE, "disabled": true, "expected": 17},
			{"name": "orange spares parent movement when soul processing is disabled", "soul": Vector2(-100, 0), "bullet": Vector2.ZERO, "soul_move": Vector2(200, 0), "bullet_move": Vector2.ZERO, "rule": BattleBullet.Rule.ORANGE, "disabled": true, "expected": 20},
		]:
			for carrier_priority in [-100, 0]:
				for soul_first in [true, false]:
					Global.player_set_hp(20)
					var carrier := MovingCarrier.new()
					carrier.position = test.soul
					carrier.process_physics_priority = carrier_priority
					var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
					soul.speed = 0.0
					soul.movement_enabled = false
					carrier.add_child(soul)
					var bullet: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
					bullet.position = test.bullet
					bullet.velocity = Vector2.ZERO
					bullet.rule = test.get("rule", BattleBullet.Rule.WHITE)
					bullet.destroy_on_contact = false
					if soul_first:
						add_child(carrier)
						add_child(bullet)
					else:
						add_child(bullet)
						add_child(carrier)
					for frame in range(3): await get_tree().physics_frame
					soul.movement_enabled = true
					if test.has("disabled"): soul.set_physics_process(false)
					carrier.velocity = test.soul_move * fps
					bullet.velocity = test.bullet_move * fps
					bullet.lifetime = float(test.get("lifetime", 2.0)) / fps
					await get_tree().physics_frame
					await get_tree().physics_frame
					carrier.velocity = Vector2.ZERO
					if is_instance_valid(bullet): bullet.set_physics_process(false)
					check(Global.player_data.hp == test.expected, "parent-driven soul: %s at %d Hz (parent priority %d, soul first %s, HP=%d)" % [test.name, fps, carrier_priority, soul_first, Global.player_data.hp])
					carrier.queue_free()
					if is_instance_valid(bullet) and not bullet.is_queued_for_deletion(): bullet.queue_free()
					await get_tree().process_frame


func test_spawn_frame_soul_motion() -> void:
	for fps in [30, 60, 144]:
		await set_physics_rate(fps)
		for test in [
			{"name": "earlier crossing does not affect new bullet", "pre": Vector2(100, 0), "post": Vector2(100, 0), "bullet": Vector2.ZERO, "expected": 20},
			{"name": "earlier movement does not hit nearby bullet", "pre": Vector2(100, 0), "post": Vector2(100, 0), "bullet": Vector2(112, 0), "expected": 20},
			{"name": "movement after spawn still hits", "pre": Vector2(-100, 0), "post": Vector2(100, 0), "bullet": Vector2.ZERO, "expected": 17},
			{"name": "movement before and after spawn is clipped", "pre": Vector2(-50, 0), "post": Vector2(100, 0), "bullet": Vector2.ZERO, "expected": 17},
			{"name": "soul created after bullet can cross it", "pre": Vector2(-100, 0), "post": Vector2(100, 0), "bullet": Vector2.ZERO, "new_soul": true, "expected": 17},
			{"name": "bullet parent moves after spawn", "pre": Vector2.ZERO, "post": Vector2.ZERO, "bullet": Vector2(-100, 0), "carrier_move": Vector2(200, 0), "expected": 17},
		]:
			Global.player_set_hp(20)
			var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
			soul.position = Vector2(-100, 0)
			soul.movement_enabled = true
			if not test.has("new_soul"):
				add_child(soul)
				soul.set_physics_process(false)
			var carrier := MovingCarrier.new()
			add_child(carrier)
			for frame in range(3): await get_tree().physics_frame
			# The soul's frame-start snapshot has run, but node physics callbacks
			# have not. Move and spawn in this same real physics frame.
			soul.position = test.pre
			var bullet: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
			bullet.position = test.bullet
			bullet.velocity = Vector2.ZERO
			bullet.destroy_on_contact = false
			carrier.add_child(bullet)
			if test.has("new_soul"):
				add_child(soul)
				soul.set_physics_process(false)
			soul.position = test.post
			if test.has("carrier_move"): carrier.velocity = test.carrier_move * fps
			await get_tree().physics_frame
			carrier.velocity = Vector2.ZERO
			if is_instance_valid(bullet): bullet.set_physics_process(false)
			check(Global.player_data.hp == test.expected, "spawn frame: %s at %d Hz (HP=%d)" % [test.name, fps, Global.player_data.hp])
			soul.queue_free()
			carrier.queue_free()
			await get_tree().process_frame


func test_disabled_bullet_monitoring() -> void:
	for fps in [30, 144]:
		await set_physics_rate(fps)
		for kind in ["linear", "rotating", "pulse"]:
			Global.player_set_hp(20)
			var soul: BattleSoul = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
			soul.position = Vector2(20, 0) if kind == "pulse" else Vector2.ZERO
			soul.movement_enabled = true
			add_child(soul)
			soul.set_physics_process(false)
			for i in range(3): await get_tree().physics_frame
			var bullet: BattleBullet
			if kind == "linear":
				bullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
				bullet.position = Vector2(-100, 0)
				bullet.velocity = Vector2(200 * fps, 0)
			else:
				var pattern := PatternBullet.new()
				pattern.velocity = Vector2.ZERO
				if kind == "rotating":
					pattern.shape_type = PatternBullet.Shape.BONE
					pattern.length = 80
					pattern.width = 4
					pattern.angular_velocity = PI * fps
				else:
					pattern.shape_type = PatternBullet.Shape.PULSE
					pattern.radius = 2
					pattern.width = 2
					pattern.expansion_speed = 40 * fps
				bullet = pattern
			bullet.monitoring = false
			bullet.destroy_on_contact = false
			add_child(bullet)
			for i in range(3): await get_tree().physics_frame
			bullet.set_physics_process(false)
			check(Global.player_data.hp == 20, "disabled monitoring prevents %s damage at %d Hz (HP=%d)" % [kind, fps, Global.player_data.hp])
			# Re-enable while overlapping to ensure normal damage is restored.
			bullet.velocity = Vector2.ZERO
			if kind == "pulse":
				var pulse := bullet as PatternBullet
				pulse.expansion_speed = 0
				pulse.radius = 20
				pulse.circle.radius = 22
			else:
				bullet.position = Vector2.ZERO
				if kind == "rotating": (bullet as PatternBullet).angular_velocity = 0
			bullet.monitoring = true
			bullet.set_physics_process(true)
			for i in range(4): await get_tree().physics_frame
			check(Global.player_data.hp == 17, "re-enabled monitoring restores %s damage at %d Hz (HP=%d)" % [kind, fps, Global.player_data.hp])
			soul.queue_free()
			if is_instance_valid(bullet) and not bullet.is_queued_for_deletion(): bullet.queue_free()
			await get_tree().process_frame
