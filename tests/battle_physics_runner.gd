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
