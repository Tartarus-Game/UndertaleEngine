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


func continue_to_turn(battle: Battle) -> void:
	battle.box_typer.skip()
	await press("ui_accept")
	if battle.battle_get_state() == Battle.BATTLE_STATE.MESSAGE:
		battle.box_typer.skip()
		await press("ui_accept")


func run_tests() -> void:
	await test_timing()
	await test_movement()
	test_inventory_save()
	test_screen_groups()
	await test_battle()
	await test_overworld_round_trip()
	AudioManager.stop_all_sfx()
	AudioManager.SEP.stream = null
	await get_tree().create_timer(0.1).timeout
	if failures.is_empty():
		print("All engine integration and timing tests passed.")
	else:
		print("Failed tests: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func test_timing() -> void:
	var typer: TextTyper = preload("res://auto_load/text/TextTyper.tscn").instantiate()
	add_child(typer)
	typer.set_process(false)
	typer.sound = null
	var text_font := typer.get_theme_font("normal_font") as FontVariation
	check(text_font != null and not text_font.fallbacks.is_empty() and text_font.fallbacks[0].has_char(0x68c0), "the typewriter has a Chinese font fallback")
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
		var walker: OverworldChar = preload("res://overworld/OverworldFrisk.tscn").instantiate()
		walker.position = Vector2(0, 200)
		add_child(walker)
		soul.arena = Rect2(-1000, -1000, 2000, 2000)
		soul.movement_enabled = true
		Input.action_press("ui_right")
		for frame in range(fps / 2 + 1): await get_tree().physics_frame
		soul.set_physics_process(false)
		walker.set_physics_process(false)
		Input.action_release("ui_right")
		check(absf(soul.position.x - 90.0) < 8.0, "soul moves about 90 pixels in half a second at %d physics ticks/s (got %.2f)" % [fps, soul.position.x])
		check(absf(walker.position.x - 90.0) < 8.0, "overworld player moves about 90 pixels in half a second at %d physics ticks/s" % fps)
		soul.queue_free()
		walker.queue_free()
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
	if FileAccess.file_exists(directory + "file991.bak"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(directory + "file991.bak"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	Global.player_set_hp(20)
	var candy := ItemManager.item_get("monster_candy")
	Global.player_set_hp(5)
	candy.use()
	check(Global.player_data.hp == 15 and candy.consumable, "Monster Candy heals 10 HP and is consumable")
	ItemManager.item_get("butts_pie").use()
	check(Global.player_data.hp == 20, "Butterscotch Pie restores full HP")
	Global.player_set_hp(20)


func test_screen_groups() -> void:
	var screen := Screen.new()
	var manager := ScreenManagerNode.new()
	add_child(manager)
	manager.add_child(screen)
	var other := Screen.new()
	manager.add_child(other)
	var first := Node.new()
	var second := Node.new()
	var third := Node.new()
	screen.add_child(first)
	screen.add_child(second)
	screen.add_child(third)
	var selected: Array[int] = []
	screen.add_button(first, Callable(), func(): selected.append(0), Callable(), 0)
	screen.add_button(second, Callable(), func(): selected.append(1), Callable(), 0)
	screen.add_button(third, Callable(), func(): selected.append(2), Callable(), 1)
	manager.register_screen(screen)
	manager.register_screen(other)
	screen.navigate(1)
	check(screen.get_active_button_index() == 1 and selected.back() == 1, "screen navigation selects within the active group")
	screen.set_active_group(1)
	check(screen.get_active_button_index() == 0 and selected.back() == 2, "switching groups selects the new group's first button")
	manager.set_active_screen(other)
	check(not screen.is_active() and other.is_active(), "only the selected screen is active")
	manager.queue_free()


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
	check(not battle.box_typer.fit_content and battle.box_typer.scroll_active, "long battle messages stay inside a scrollable box")
	check(Global.player_get_item(0) == "PROMISE" and Global.player_get_item(99) == null, "inventory indexes work")
	var dummy := battle.battle_get_enemy(0)
	dummy.data.defense = 4.0
	check(is_equal_approx(dummy.take_damage(5.0), 1.0), "enemy defense reduces damage")
	dummy._hp = dummy._hp_max
	dummy.data.defense = 0.0
	dummy.action_set(1, "Smile", func(): return "* You smiled.")
	check(dummy.perform_action(1) == "* You smiled.", "enemy ACT callbacks can supply their own response")
	dummy.data.can_flee = false
	battle.battle_set_menu(Battle.BATTLE_MENU.MERCY)
	battle._set_mercy_choice(1)
	battle._resolve_mercy()
	check(battle._message_next == "turn", "an enemy can prevent the player from fleeing")
	dummy.data.can_flee = true
	battle.battle_state = Battle.BATTLE_STATE.MENU
	battle.battle_set_menu(Battle.BATTLE_MENU.BUTTON)
	var inventory: Array[String] = Global.player_get_items().duplicate()
	battle.box_transition_duration = 0.0
	battle.battle_set_menu(Battle.BATTLE_MENU.ITEM)
	battle.battle_set_item_choice(4)
	Global.player_set_hp(5)
	battle._use_item()
	check(Global.player_data.hp == 15 and Global.player_get_item_count() == inventory.size() - 1, "using a healing item heals and consumes its slot")
	Global.player_get_items().assign(inventory)
	battle.battle_state = Battle.BATTLE_STATE.MENU
	battle.battle_set_menu(Battle.BATTLE_MENU.ITEM)
	battle.battle_set_item_choice(4)
	battle._drop_item()
	check(Global.player_get_item_count() == inventory.size() - 1, "dropping an item removes its slot")
	Global.player_get_items().assign(inventory)
	Global.player_set_hp(20)
	battle.battle_state = Battle.BATTLE_STATE.MENU
	battle.battle_set_menu(Battle.BATTLE_MENU.BUTTON)
	dummy.wave_scene = preload("res://tests/TestWave.tscn")
	battle.start_enemy_turn()
	check(battle.active_wave.get_script().resource_path == "res://tests/TestWave.gd", "an enemy can supply its own wave")
	battle.end_enemy_turn()
	dummy.wave_scene = null
	await get_tree().process_frame
	battle.box_transition_duration = 0.05
	battle.start_enemy_turn()
	check(battle.battle_get_state() == Battle.BATTLE_STATE.TRANSITION, "the box animates before the wave begins")
	await battle.turn_started
	check(battle.battle_get_state() == Battle.BATTLE_STATE.ENEMY_TURN, "the wave begins after the box animation")
	battle.end_enemy_turn()
	await battle.turn_finished
	check(battle.battle_get_state() == Battle.BATTLE_STATE.MENU, "the menu returns after the box expands")
	battle.box_transition_duration = 0.0
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
	await continue_to_turn(battle)
	check(battle.battle_get_state() == Battle.BATTLE_STATE.ENEMY_TURN, "continuing starts the enemy turn")
	check(battle.bullet_clip.clip_contents and battle.bullet_clip.size == battle.soul.arena.size, "bullets are clipped to the battle arena")
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
	Global.player_data.def = 2
	battle.soul.advance_invulnerability(1.0)
	var hp_before_defense := int(Global.player_data.hp)
	battle.soul.take_damage(3)
	check(int(Global.player_data.hp) == hp_before_defense - 1, "player defense reduces incoming damage")
	Global.player_data.def = 0

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
	await continue_to_turn(battle)
	battle.end_enemy_turn()
	await press("ui_right")
	await press("ui_right")
	await press("ui_accept")
	await press("ui_accept")
	check(battle.battle_get_enemy_count() == 1, "spare removes only spareable enemies")
	await continue_to_turn(battle)
	battle.end_enemy_turn()
	await press("ui_left")
	await press("ui_accept")
	await press("ui_accept")
	check(battle.battle_get_menu() == Battle.BATTLE_MENU.ITEM_COMMAND, "item opens use/info/drop choices")
	await press("ui_right")
	await press("ui_accept")
	check(battle.battle_get_menu() == Battle.BATTLE_MENU.ITEM_INFO, "item info is shown without consuming the turn")
	battle.box_typer.skip()
	await press("ui_accept")
	check(battle.battle_get_menu() == Battle.BATTLE_MENU.ITEM_COMMAND, "closing item info returns to the item commands")
	await press("ui_accept")
	check(battle.battle_get_state() == Battle.BATTLE_STATE.MESSAGE, "using an item advances to a message")
	await continue_to_turn(battle)
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
	second.box_transition_duration = 0.0
	add_child(second)
	second.start_enemy_turn()
	second.soul.take_damage(3)
	check(second.battle_get_state() == Battle.BATTLE_STATE.RESULT and second._result == "lost", "zero HP ends the battle in defeat")
	second.queue_free()
	await get_tree().process_frame
	Global.player_set_hp(20)


func test_overworld_round_trip() -> void:
	var tree := get_tree()
	var test_scene := tree.current_scene
	var world: Node2D = preload("res://overworld/test_level/test.tscn").instantiate()
	tree.root.add_child(world)
	tree.current_scene = world
	var player: OverworldFrisk = world.get_node("OverworldFrisk")
	var trigger: OverworldTrigger = world.get_node("EncounterTrigger")
	player.position = trigger.position - Vector2(20, 0)
	player.facing = Vector2.RIGHT
	for frame in range(3): await tree.physics_frame
	player.interaction_ray.target_position = Vector2(32, 0)
	player.interaction_ray.force_raycast_update()
	check(player.interaction_ray.get_collider() == trigger, "the overworld interaction ray finds the encounter")
	player.position = trigger.position
	player.interaction_ray.force_raycast_update()
	check(player.interaction_ray.get_collider() == trigger, "interaction still works when the player overlaps a trigger")
	player.position = trigger.position - Vector2(20, 0)
	for frame in range(2): await tree.physics_frame
	var original_id := world.get_instance_id()
	var original_position := player.position
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	Input.parse_input_event(event)
	await tree.create_timer(0.22).timeout
	check(tree.current_scene is Battle and tree.current_scene.battle_get_menu() == Battle.BATTLE_MENU.BUTTON, "the encounter confirm does not activate a battle menu")
	event.pressed = false
	Input.parse_input_event(event)
	check(tree.current_scene is Battle and not world.is_inside_tree(), "interacting suspends the overworld and opens battle")
	EncounterManager.finish_battle("won")
	for frame in range(3): await tree.process_frame
	check(tree.current_scene == world and world.get_instance_id() == original_id, "battle restores the same overworld scene instance")
	check(player.position == original_position and EncounterManager.last_result == "won", "overworld position and battle result survive the encounter")
	check("won" in world.get_node("Status").text, "the restored overworld receives the battle result")
	tree.current_scene = test_scene
	tree.root.remove_child(world)
	world.queue_free()
	await tree.process_frame
