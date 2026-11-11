extends Node

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error("FAIL: " + description)


func press(action: String) -> void:
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func run_tests() -> void:
	await test_timing()
	await test_movement()
	test_inventory_save()
	await test_battle()
	AudioManager.SEP.stop()
	AudioManager.SEP.stream = null
	await get_tree().create_timer(0.1).timeout
	if failures.is_empty():
		print("All battle and timing tests passed.")
	else:
		print("Failed tests: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func test_timing() -> void:
	var typer: TextTyper = preload("res://auto_load/text/TextTyper.tscn").instantiate()
	add_child(typer)
	typer.set_process(false)
	typer.sound = null
	for fps in [30, 60, 144]:
		typer.clear_text()
		typer.text_add("abcdefghijklmnopqrstuvwxyz0123456789")
		typer.next_text()
		for frame in range(fps): typer.advance_text(1.0 / fps)
		check(typer.visible_characters == 20, "typewriter reveals 20 characters in one second at %d FPS (got %d)" % [fps, typer.visible_characters])
	typer.clear_text()
	typer.text_add("abc", func(t): t.sleep_text(0.25))
	typer.next_text()
	typer.advance_text(0.35)
	check(typer.visible_characters == 2, "typewriter consumes only the remaining time after a pause")
	typer.clear_text()
	typer.text_add("abc", func(t): t.pause_text())
	typer.text_add("def")
	typer.next_text()
	typer.advance_text(1.0)
	check(typer.visible_characters == 3 and typer.text == "abc", "a paused segment waits for confirmation")
	typer.resume_text()
	typer.advance_text(1.0)
	check(typer.visible_characters == 6 and typer.text == "abcdef", "resuming continues the queued segment")
	typer.queue_free()

	for fps in [30, 60, 144]:
		var meter := FightMeter.new()
		add_child(meter)
		meter.set_process(false)
		meter.start()
		for frame in range(fps): meter._process(1.0 / fps)
		check(is_equal_approx(meter.elapsed, 1.0), "fight meter advances in seconds at %d FPS" % fps)
		check(is_equal_approx(meter.accuracy(), 2.0 / 3.0), "fight accuracy is independent of FPS")
		meter.queue_free()
		var bullet: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
		add_child(bullet)
		bullet.set_physics_process(false)
		for frame in range(fps): bullet._physics_process(1.0 / fps)
		check(absf(bullet.position.x + 115.0) < 0.01, "bullet travels 115 pixels per second at %d FPS" % fps)
		bullet.queue_free()
	await get_tree().process_frame


func test_movement() -> void:
	var original_tick_rate := Engine.physics_ticks_per_second
	for fps in [30, 60, 144]:
		Engine.physics_ticks_per_second = fps
		var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
		add_child(soul)
		soul.arena = Rect2(-1000, -1000, 2000, 2000)
		soul.movement_enabled = true
		Input.action_press("ui_right")
		for frame in range(fps / 2 + 1): await get_tree().physics_frame
		soul.set_physics_process(false)
		Input.action_release("ui_right")
		check(absf(soul.position.x - 90.0) < 8.0, "soul moves about 90 pixels in half a second at %d physics ticks/s (got %.2f)" % [fps, soul.position.x])
		soul.queue_free()
		await get_tree().process_frame
	Engine.physics_ticks_per_second = original_tick_rate


func test_inventory_save() -> void:
	var directory := "user://engine_tests/"
	Global.player_set_hp(12)
	Global.storage_save(directory, 991)
	Global.player_get_items().clear()
	Global.player_set_hp(1)
	Global.storage_load(directory, 991)
	check(Global.player_data.hp == 12 and Global.player_get_item(0) == "PROMISE", "save/load restores HP and inventory")
	Global.player_get_items().append("EXTRA")
	check(Global.player_data.items.size() == Global.player_get_item_count(), "loaded inventory stays linked to player data")
	Global.player_get_items().pop_back()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory + "file991"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	Global.player_set_hp(20)


func test_battle() -> void:
	Global.player_set_hp(20)
	EncounterManager.current_id = -1
	var battle: Battle = preload("res://battle/Battle.tscn").instantiate()
	var ui: BattleUI = battle.get_node("UIManager/UI")
	ui.button_choice_sound = null
	ui.button_accept = null
	var prompt: TextTyper = battle.get_node("BoxTyper")
	prompt.sound = null
	add_child(battle)
	await get_tree().process_frame
	check(battle.battle_get_enemy_count() == 2, "encounter creates both enemies")
	check(Global.player_get_item(0) == "PROMISE" and Global.player_get_item(99) == null, "inventory indexes work")
	for fps in [30, 60, 144]:
		battle.start_enemy_turn()
		var wave := battle.active_wave as ExampleWave
		wave.set_physics_process(false)
		for frame in range(fps): wave._physics_process(1.0 / fps)
		check(wave.bullet_count == 2, "wave schedules the same bullets in one second at %d FPS" % fps)
		battle.end_enemy_turn()
		await get_tree().process_frame
	battle.turn_duration = 0.25
	battle.start_enemy_turn()
	battle.active_wave.set_physics_process(false)
	battle.active_wave._physics_process(0.1)
	check(battle.battle_get_state() == Battle.BATTLE_STATE.ENEMY_TURN, "wave does not end before its duration")
	battle.active_wave._physics_process(0.15)
	check(battle.battle_get_state() == Battle.BATTLE_STATE.MENU, "wave ends and returns to the menu at its duration")
	battle.turn_duration = 6.0
	await get_tree().process_frame
	await press("ui_accept")
	check(battle.battle_get_menu() == Battle.BATTLE_MENU.FIGHT_ENEMY_CHOICE, "confirm opens fight target menu")
	await press("ui_accept")
	check(battle.battle_get_menu() == Battle.BATTLE_MENU.FIGHT_AIM, "confirm starts the fight meter")
	battle.fight_meter.elapsed = battle.fight_meter.duration / 2.0
	await press("ui_accept")
	check(battle.battle_get_state() == Battle.BATTLE_STATE.MESSAGE and battle.battle_get_enemy(0).get_hp() < 30, "fight deals damage and displays a message")
	battle.box_typer.skip()
	await press("ui_accept")
	check(battle.battle_get_state() == Battle.BATTLE_STATE.ENEMY_TURN, "continuing starts the enemy turn")
	battle.active_wave.set_physics_process(false)
	Input.action_press("ui_right")
	for frame in range(90): await get_tree().physics_frame
	Input.action_release("ui_right")
	check(battle.soul.position.x > battle.battle_box.position.x + 50, "soul moves during the enemy turn")
	check(battle.soul.global_position.x <= battle.soul.arena.end.x - 7.9, "soul stays within the arena")
	battle.soul.global_position = battle.battle_box.global_position

	# Verify the small soul hitbox with real Area2D collision signals.
	var old_hp := int(Global.player_data.hp)
	var near_miss: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
	near_miss.velocity = Vector2.ZERO
	near_miss.position = battle.soul.position + Vector2(12, 0)
	battle.bullets.add_child(near_miss)
	for frame in range(5): await get_tree().physics_frame
	check(int(Global.player_data.hp) == old_hp, "a bullet outside the small soul hitbox does not damage it")
	var bullet: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
	bullet.velocity = Vector2.ZERO
	bullet.position = battle.soul.position
	battle.bullets.add_child(bullet)
	for frame in range(5): await get_tree().physics_frame
	check(int(Global.player_data.hp) == old_hp - 3, "bullet collision damages the soul")
	check(not battle.soul.take_damage(3), "invulnerability blocks repeat damage")
	battle.soul.advance_invulnerability(1.0)
	check(battle.soul.take_damage(3), "damage resumes after invulnerability expires")

	battle.end_enemy_turn()
	check(battle.battle_get_state() == Battle.BATTLE_STATE.MENU, "enemy turn returns to the menu")
	await press("ui_right")
	await press("ui_accept")
	await press("ui_down")
	await press("ui_accept")
	await press("ui_right")
	var enemy := battle.battle_get_act_enemy_choice()
	await press("ui_accept")
	check(enemy.spareable, "the test enemy becomes spareable after its ACT")
	battle.box_typer.skip()
	await press("ui_accept")
	battle.end_enemy_turn()
	await press("ui_right")
	await press("ui_right")
	await press("ui_accept")
	await press("ui_accept")
	check(battle.battle_get_enemy_count() == 1, "spare removes only spareable enemies")
	battle.box_typer.skip()
	await press("ui_accept")
	battle.end_enemy_turn()
	await press("ui_left")
	await press("ui_accept")
	await press("ui_accept")
	check(battle.battle_get_state() == Battle.BATTLE_STATE.MESSAGE, "using an item advances to a message")
	battle.box_typer.skip()
	await press("ui_accept")
	battle.end_enemy_turn()
	await press("ui_left")
	await press("ui_left")
	await press("ui_accept")
	await press("ui_accept")
	battle.fight_meter.elapsed = battle.fight_meter.duration / 2.0
	await press("ui_accept")
	battle.box_typer.skip()
	await press("ui_accept")
	check(battle.battle_get_state() == Battle.BATTLE_STATE.RESULT, "winning reaches the result state")
	battle.queue_free()
	await get_tree().process_frame

	Global.player_set_hp(3)
	var second: Battle = preload("res://battle/Battle.tscn").instantiate()
	var second_ui: BattleUI = second.get_node("UIManager/UI")
	second_ui.button_choice_sound = null
	second_ui.button_accept = null
	var second_prompt: TextTyper = second.get_node("BoxTyper")
	second_prompt.sound = null
	add_child(second)
	second.start_enemy_turn()
	second.soul.take_damage(3)
	check(second.battle_get_state() == Battle.BATTLE_STATE.RESULT and second._result == "lost", "zero HP ends the battle in defeat")
	second.queue_free()
	await get_tree().process_frame
	Global.player_set_hp(20)
