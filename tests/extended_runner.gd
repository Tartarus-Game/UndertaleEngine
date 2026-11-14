extends "res://tests/test_runner.gd"


func _ready() -> void:
	call_deferred("run_extended")


func action_event(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame


func physical_key(keycode: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame


func run_extended() -> void:
	await test_custom_enemy_template()
	var menu_events := InputMap.action_get_events("ui_menu")
	var saved_bindings: Dictionary = SettingsService.bindings.duplicate(true)
	SettingsService._loading = true
	SettingsService.bind_key("ui_menu", KEY_C)
	SettingsService._loading = false
	await test_progression_and_shop()
	test_input_settings()
	await test_dialogue_and_events()
	await test_souls_and_rules()
	await test_patterns_and_waves()
	await test_invalid_saves()
	await test_save_backup_recovery()
	await test_world_save_restore()
	InputMap.action_erase_events("ui_menu")
	for event in menu_events: InputMap.action_add_event("ui_menu", event)
	SettingsService.bindings = saved_bindings
	AudioManager.stop_all_sfx()
	await get_tree().create_timer(0.15).timeout
	if failures.is_empty(): print("All extended feature tests passed.")
	else: print("Failed extended tests: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func restore_player(saved: Dictionary) -> void:
	Global.player_data = saved
	Global.player_data_items.assign(saved.items)
	Global.player_data.items = Global.player_data_items
	Global.player_hp_changed.emit(int(saved.hp), int(saved.hp_max))
	Global.player_stats_changed.emit()


func test_progression_and_shop() -> void:
	var original: Dictionary = Global.player_data.duplicate(true)
	while Global.player_get_item_count() > 6: Global.player_get_items().pop_back()
	Global.player_data.gold = 100
	ShopService.stock.assign(["toy_knife"])
	check(ShopService.buy("toy_knife"), "shop purchases stock when the player can afford it")
	check(int(Global.player_data.gold) == 70, "shop deducts the listed price")
	check(Global.equip_item("toy_knife") and Global.player_get_attack() == 23, "equipment contributes to attack")
	var slot := Global.player_get_items().find("toy_knife")
	check(ShopService.sell(slot), "shop sells an owned item")
	check(int(Global.player_data.gold) == 85 and Global.player_data.weapon == "", "selling equipment awards gold and unequips it")
	Global.player_data.exp = 0
	Global.player_data.lv = 1
	Global.player_data.hp_max = 20
	Global.player_data.hp = 10
	check(Global.award_rewards(10, 7), "earned EXP triggers the next level")
	check(Global.player_data.lv == 2 and Global.player_data.hp == 24 and Global.player_data.gold == 92, "level up and rewards update the player")
	var previous_language: String = SettingsService.language
	SettingsService._loading = true
	SettingsService.set_language("zh_CN")
	check(SettingsService.text("shop.buy") == "购买", "language setting resolves translated UI text")
	SettingsService.set_language(previous_language)
	SettingsService._loading = false
	restore_player(original)
	await get_tree().process_frame


func test_input_settings() -> void:
	var old_path: String = SettingsService.settings_path
	var old_keys: Dictionary = SettingsService.bindings.duplicate(true)
	var old_joy: Dictionary = SettingsService.joy_bindings.duplicate(true)
	var old_events := InputMap.action_get_events("ui_up")
	var path := "user://input_test_%d.cfg" % Time.get_ticks_usec()
	SettingsService.settings_path = path
	SettingsService.bind_key("ui_up", KEY_W)
	WorldMenu.busy = true
	WorldMenu.state = "settings"
	WorldMenu.selected = 3
	WorldMenu._activate()
	var joy_event := InputEventJoypadButton.new()
	joy_event.device = -1
	joy_event.button_index = JOY_BUTTON_Y
	joy_event.pressed = true
	WorldMenu._unhandled_input(joy_event)
	check(WorldMenu.capture_action.is_empty(), "the settings menu captures a gamepad button")
	WorldMenu.busy = false
	WorldMenu.state = "root"
	InputMap.action_erase_events("ui_up")
	SettingsService.bindings.clear()
	SettingsService.joy_bindings.clear()
	SettingsService.load_settings()
	var key_found := false
	var joy_found := false
	for event in InputMap.action_get_events("ui_up"):
		if event is InputEventKey and event.physical_keycode == KEY_W: key_found = true
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_Y: joy_found = true
	check(key_found and joy_found, "keyboard and gamepad bindings survive settings reload")
	InputMap.action_erase_events("ui_up")
	for event in old_events: InputMap.action_add_event("ui_up", event)
	SettingsService.bindings = old_keys
	SettingsService.joy_bindings = old_joy
	SettingsService.settings_path = old_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_dialogue_and_events() -> void:
	var typer: TextTyper = DialogueService.typer
	typer.clear_text()
	typer.sound = null
	typer.delta_time = 0.05
	typer.text_add_markup("A{wait:0.3}B")
	typer.next_text()
	typer.advance_text(0.2)
	check(typer.visible_characters == 1, "inline wait delays the next character")
	typer.advance_text(0.2)
	check(typer.visible_characters == 2, "inline wait consumes seconds and then resumes")
	typer.clear_text()
	typer.text_add_markup("{angle:15}{speed:0.1}X{pause}Y")
	typer.next_text()
	typer.advance_text(1.0)
	check(typer.pause and is_equal_approx(typer.rotation, deg_to_rad(15.0)), "inline commands set rotation and pause the dialogue")
	typer.resume_text()
	typer.advance_text(1.0)
	check(typer.visible_characters == 2, "inline pause resumes the remaining text")
	typer.rotation = 0.0
	typer.delta_time = 0.05
	var selected := [-99]
	DialogueService.completed.connect(func(choice): selected[0] = choice, CONNECT_ONE_SHOT)
	DialogueService.present("* Choose", ["Yes", "No"])
	await get_tree().process_frame
	check(DialogueService.busy, "dialogue opens")
	DialogueService.typer.skip()
	await action_event("ui_right")
	await action_event("ui_accept")
	check(selected[0] == 1 and not DialogueService.busy, "dialogue presents and returns a selected branch")
	EventService.run([
		{"type": "set_flag", "key": "test_path", "value": 3},
		{"type": "if_flag", "key": "test_path", "value": 3, "then": [{"type": "set_flag", "key": "test_branch", "value": true}]}
	])
	await get_tree().process_frame
	check(Global.get_flag("test_branch") == true and not EventService.running, "event conditions execute the chosen branch")
	Global.world_state.flags.erase("test_path")
	Global.world_state.flags.erase("test_branch")


func test_souls_and_rules() -> void:
	var original: Dictionary = Global.player_data.duplicate(true)
	var soul: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
	add_child(soul)
	soul.set_physics_process(false)
	soul.movement_enabled = true
	var area := soul.get_node("HurtBox") as Area2D
	var bullet: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
	add_child(bullet)
	bullet.set_physics_process(false)
	bullet.destroy_on_contact = false
	Global.player_data.def = 0
	Global.player_data.armor = ""
	Global.player_data.hp_max = 20
	Global.player_set_hp(20)
	bullet.rule = BattleBullet.Rule.BLUE
	soul.is_moving = false
	bullet._try_contact(area)
	check(Global.player_data.hp == 20, "blue bullet is safe while the soul is still")
	soul.is_moving = true
	bullet._try_contact(area)
	check(Global.player_data.hp == 17, "blue bullet hurts a moving soul")
	soul.invulnerability_remaining = 0.0
	bullet.rule = BattleBullet.Rule.ORANGE
	bullet._try_contact(area)
	check(Global.player_data.hp == 17, "orange bullet is safe while the soul moves")
	soul.is_moving = false
	bullet._try_contact(area)
	check(Global.player_data.hp == 14, "orange bullet hurts a still soul")
	soul.set_mode("green")
	soul.shield_direction = Vector2.UP
	soul.invulnerability_remaining = 0.0
	bullet.rule = BattleBullet.Rule.WHITE
	bullet.position = Vector2(0, -6)
	bullet._try_contact(area)
	check(Global.player_data.hp == 14, "green soul blocks a bullet on its shield side")
	for fps in [30, 60, 144]:
		Global.player_set_hp(20)
		Global.player_data.kr = 12.0
		soul.karma_timer = 0.0
		for frame in range(fps): soul.advance_karma(1.0 / fps)
		check(Global.player_data.hp == 14 and is_equal_approx(Global.player_data.kr, 6.0), "KR drains six HP per second at %d updates/s" % fps)
	soul.set_mode("red")
	bullet.karma = true
	for fps in [30, 60, 144]:
		Global.player_set_hp(20)
		Global.player_data.kr = 0.0
		bullet._contact_ticks.clear()
		bullet._try_contact(area)
		for frame in range(fps): bullet._try_contact(area, 1.0 / fps)
		check(is_equal_approx(Global.player_data.kr, 9.0), "continuous KR contact adds the same amount at %d updates/s" % fps)
	var target: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
	target.velocity = Vector2.ZERO
	target.position = Vector2(50, 0)
	add_child(target)
	target.shootable = true
	check(target.is_in_group("shootable_bullets"), "shootable state can be enabled after spawning")
	var projectile := SoulProjectile.new()
	projectile.velocity = Vector2(360, 0)
	add_child(projectile)
	projectile.set_physics_process(false)
	projectile._physics_process(0.25)
	check(target.is_queued_for_deletion(), "yellow soul projectiles can hit shootable bullets without tunneling past their center")
	bullet.queue_free()
	soul.queue_free()
	await get_tree().process_frame
	var tick_rate := Engine.physics_ticks_per_second
	for fps in [30, 60, 144]:
		Engine.physics_ticks_per_second = fps
		var falling: BattleSoulRed = preload("res://battle/battle_soul/BattleSoulRed.tscn").instantiate()
		add_child(falling)
		falling.arena = Rect2(-500, -500, 1000, 1000)
		falling.movement_enabled = true
		falling.set_mode("blue")
		for frame in range(roundi(fps * 0.25)): await get_tree().physics_frame
		falling.set_physics_process(false)
		check(absf(falling.position.y - 35.0) < 12.0, "blue soul falls consistently at %d physics ticks/s (%.2f)" % [fps, falling.position.y])
		falling.queue_free()
		await get_tree().process_frame
	Engine.physics_ticks_per_second = tick_rate
	restore_player(original)


func test_patterns_and_waves() -> void:
	for fps in [30, 60, 144]:
		var bone := PatternBullet.new()
		bone.velocity = Vector2(100, 0)
		bone.angular_velocity = 1.0
		bone.lifetime = 10.0
		add_child(bone)
		bone.set_physics_process(false)
		for frame in range(fps): bone._physics_process(1.0 / fps)
		check(absf(bone.position.x - 100.0) < 0.01 and absf(bone.rotation - 1.0) < 0.01, "bone motion and rotation use seconds at %d updates/s" % fps)
		bone.queue_free()
		var pellet := PatternBullet.new()
		pellet.shape_type = PatternBullet.Shape.PELLET
		pellet.velocity = Vector2.ZERO
		pellet.launch_velocity = Vector2(100, 0)
		pellet.warning = 0.25
		pellet.lifetime = 10.0
		add_child(pellet)
		pellet.set_physics_process(false)
		for frame in range(fps): pellet._physics_process(1.0 / fps)
		check(absf(pellet.position.x - 75.0) < 0.01, "pellet crosses its launch time correctly at %d updates/s" % fps)
		pellet.queue_free()
	EncounterManager.current_id = -1
	var battle: Battle = preload("res://battle/Battle.tscn").instantiate()
	battle.box_transition_duration = 0.0
	add_child(battle)
	await get_tree().process_frame
	var target := battle.battle_get_enemy(0)
	var old_position: Vector2 = target.global_position
	var old_hp: float = target.get_hp()
	target.projectile_target = true
	# Enemy's larger radius puts its surface before the bullet's, even though
	# the bullet's center is closer to the shot's origin.
	target.global_position = Vector2(40, 0)
	var distant_bullet: BattleBullet = preload("res://battle/bullets/BattleBullet.tscn").instantiate()
	distant_bullet.position = Vector2(35, 0)
	distant_bullet.velocity = Vector2.ZERO
	distant_bullet.shootable = true
	add_child(distant_bullet)
	distant_bullet.set_physics_process(false)
	battle.graze_enabled = true
	battle.soul.grazed.emit(distant_bullet)
	check(battle.tp_value == 1, "graze signal adds battle TP")
	battle.set_tp(999)
	check(battle.tp_value == battle.tp_max and battle.spend_tp(30) and battle.tp_value == battle.tp_max - 30, "TP is capped and can be spent")
	check(not battle.spend_tp(999), "TP cannot be spent beyond its balance")
	var ui: BattleUI = battle.get_node("UIManager/UI")
	check(ui.tp_label.visible and ui.tp_label.text == "TP 70/100", "TP display follows the battle state")
	battle.graze_enabled = false
	var shot := SoulProjectile.new()
	shot.velocity = Vector2(12000, 0)
	shot.battle = battle
	add_child(shot)
	shot.set_physics_process(false)
	shot._physics_process(1.0 / 60.0)
	check(target.get_hp() < old_hp and not distant_bullet.is_queued_for_deletion(), "yellow projectile hits the first surface across enemies and bullets")
	if not distant_bullet.is_queued_for_deletion(): distant_bullet.queue_free()
	if not shot.is_queued_for_deletion(): shot.queue_free()
	target._hp = old_hp
	var enemy_shape := RectangleShape2D.new()
	enemy_shape.size = Vector2(8, 60)
	target.projectile_hit_shape = enemy_shape
	target.global_position = Vector2(50, 0)
	shot = SoulProjectile.new()
	shot.position = Vector2(0, 20)
	shot.velocity = Vector2(12000, 0)
	shot.battle = battle
	add_child(shot)
	shot.set_physics_process(false)
	shot._physics_process(1.0 / 60.0)
	check(target.get_hp() < old_hp, "yellow shot uses a configured enemy hit shape")
	if not shot.is_queued_for_deletion(): shot.queue_free()
	target._hp = old_hp
	target.projectile_hit_shape = null
	for observe_disabled in [false, true]:
		target.global_position = Vector2(50, 0)
		shot = SoulProjectile.new()
		shot.velocity = Vector2.ZERO
		shot.battle = battle
		add_child(shot)
		shot.set_physics_process(false)
		shot._physics_process(1.0 / 60.0)
		target.projectile_target = false
		target.global_position = Vector2(-50, 0)
		if observe_disabled: shot._physics_process(1.0 / 60.0)
		target.projectile_target = true
		shot._physics_process(1.0 / 60.0)
		check(target.get_hp() == old_hp and not shot.is_queued_for_deletion(), "reactivating an enemy ignores motion while disabled (observed=%s)" % observe_disabled)
		if not shot.is_queued_for_deletion():
			target.global_position = Vector2(50, 0)
			target.projectile_target = true
			shot._physics_process(1.0 / 60.0)
			check(target.get_hp() < old_hp, "reactivated enemies detect subsequent motion")
		if not shot.is_queued_for_deletion(): shot.queue_free()
		target._hp = old_hp
	target.global_position = Vector2(50, 0)
	shot = SoulProjectile.new()
	shot.velocity = Vector2.ZERO
	shot.battle = battle
	add_child(shot)
	shot.set_physics_process(false)
	target.projectile_target = false
	target.global_position = Vector2(-50, 0)
	target.projectile_target = true
	target.global_position = Vector2(50, 0)
	shot._physics_process(1.0 / 60.0)
	check(target.get_hp() < old_hp, "enemy motion after reactivation is detected in the same update")
	if not shot.is_queued_for_deletion(): shot.queue_free()
	target._hp = old_hp
	target.global_position = old_position
	target.projectile_target = false
	for index in range(1, 9): target.action_set(index, "Action %d" % index)
	battle.battle_set_act_enemy_choice(0)
	battle.battle_set_act_choice(7)
	check(battle.battle_act_choice == 7 and battle.enemy_actions.selections[1].visible, "ACT choices beyond the first page remain selectable")
	target.data.flee_chance = 0.0
	battle.mercy_choice = 1
	battle._resolve_mercy()
	check(battle._message_next == "turn", "an enemy can give the player a zero escape chance")
	battle.battle_state = Battle.BATTLE_STATE.MENU
	target.data.flee_chance = 1.0
	for enemy in battle.battle_get_enemys(): enemy.wave_scene = preload("res://tests/TestWave.tscn")
	battle.start_enemy_turn()
	check(battle.active_waves.size() == 2, "both enemies start independent waves")
	var first := battle.active_waves[0]
	var second := battle.active_waves[1]
	first.set_physics_process(false)
	second.set_physics_process(false)
	first._physics_process(6.0)
	check(battle.active_waves.size() == 1 and battle.battle_state == Battle.BATTLE_STATE.ENEMY_TURN, "the turn continues until every wave finishes")
	var triangle := PackedVector2Array([Vector2(-100,-60), Vector2(100,-60), Vector2(0,60)])
	check(battle.set_arena_polygon(triangle) and battle.battle_box.polygon_edges.size() == 3, "polygon arena creates its collision edges")
	battle.soul.global_position = battle.battle_box.global_position + Vector2(90, 45)
	battle.soul.clamp_to_arena()
	check(Geometry2D.is_point_in_polygon(battle.soul.global_position, battle.soul.arena_polygon), "soul is returned inside a polygon arena")
	second._physics_process(6.0)
	check(battle.battle_state == Battle.BATTLE_STATE.MENU, "the menu returns after all waves finish")
	battle.start_enemy_turn()
	var wall := BattlePatterns.wall(battle, Vector2(100, 300), 3, Vector2(20, 0), 40, Vector2(50, 0))
	var laser := BattlePatterns.blaster(battle, Vector2(100, 320), Vector2(400, 320), 0.5, 1.0)
	var ring := BattlePatterns.ring(battle, Vector2(320, 320), 8, 50, 20, 1.0)
	check(wall.size() == 3 and laser.warning == 0.5 and ring.get_child_count() == 8, "attack helpers instantiate bones, charged lasers and rings")
	var pellet := BattlePatterns.targeted_pellet(battle, Vector2(0, 0), Vector2(80, 0), Vector2(0, 100), 0.3, 0.5)
	var gun := BattlePatterns.gun(battle, Vector2(200, 200), 0.2, 0.3, 0.1, BattleBullet.Rule.BLUE, {"radius": 12.0, "show_horizontal": false})
	check(pellet.get_parent() == battle.effects and pellet.rest_position == Vector2(80, 0), "targeted pellet factory configures its route")
	check(gun.rule == BattleBullet.Rule.BLUE and gun.radius == 12.0 and not gun.show_horizontal, "gun factory applies attack options")
	var cone := BattlePatterns.bone_cone(battle, Vector2(100, 100), 0.0, PI / 2.0, 0.4, 100.0, BattleBullet.Rule.BLUE, {"speed": 30.0, "karma": true})
	check(cone.get_parent() == battle.effects and cone.rule == BattleBullet.Rule.BLUE and cone.speed == 30.0 and cone.karma, "bone cone factory applies attack options")
	battle.end_enemy_turn()
	target._hp = 1.0
	target.data.exp_reward = 4
	battle.damage_enemy_from_projectile(target, 1.0)
	check(battle.battle_get_enemy_count() == 1 and battle.reward_exp == 4, "shooting a target can defeat it and accumulate rewards")
	battle.queue_free()
	await get_tree().process_frame


func test_invalid_saves() -> void:
	var old_player: Dictionary = Global.player_data.duplicate(true)
	var old_world: Dictionary = Global.world_state.duplicate(true)
	var old_slot: int = Global.current_save_slot
	var directory := "user://invalid_save_tests/"
	DirAccess.make_dir_recursive_absolute(directory)
	Global.player_set_hp(19)
	Global.set_flag("save_test", "unchanged")
	var before_player: Dictionary = Global.player_data.duplicate(true)
	var before_world: Dictionary = Global.world_state.duplicate(true)
	var file := FileAccess.open(directory.path_join("file1"), FileAccess.WRITE)
	file.store_var({"version": 1, "player": {"hp": 1, "items": []}, "world": {"flags": []}})
	file.close()
	check(not Global.storage_load(directory, 1), "malformed world state is rejected")
	check(Global.player_data == before_player and Global.world_state == before_world and Global.current_save_slot == old_slot, "invalid save does not partially modify state")
	file = FileAccess.open(directory.path_join("file2"), FileAccess.WRITE)
	file.store_var({"version": 1, "player": {"hp": 1, "items": []}, "world": {"flags": {}, "scene": "res://missing_room.tscn", "position": Vector2.ZERO}})
	file.close()
	check(not await Global.restore_world(directory, 2), "save with missing room cannot be restored")
	check(Global.player_data == before_player and Global.world_state == before_world and Global.current_save_slot == old_slot, "failed room restoration leaves the previous state intact")
	var invalid := [
		{"version": 99, "player": {}},
		{"version": 1, "world": {}},
		{"version": 1, "player": {"hp": 1, "items": [42]}},
	]
	for data in invalid:
		file = FileAccess.open(directory.path_join("file4"), FileAccess.WRITE)
		file.store_var(data)
		file.close()
		check(not Global.storage_load(directory, 4), "invalid version, missing player or invalid inventory is rejected")
		check(Global.player_data == before_player and Global.world_state == before_world and Global.current_save_slot == old_slot, "rejected save leaves state unchanged")
	file = FileAccess.open(directory.path_join("file3"), FileAccess.WRITE)
	file.store_var({"hp": 12, "items": ["PROMISE"]})
	file.close()
	check(Global.storage_load(directory, 3) and Global.player_data.hp == 12 and Global.player_get_item(0) == "PROMISE", "legacy player-only saves still load")
	for slot in [1, 2, 3, 4]: DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join("file" + str(slot))))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	Global.world_state = old_world
	Global.current_save_slot = old_slot
	restore_player(old_player)


func test_save_backup_recovery() -> void:
	var old_player: Dictionary = Global.player_data.duplicate(true)
	var old_world: Dictionary = Global.world_state.duplicate(true)
	var old_slot: int = Global.current_save_slot
	var old_recovered: bool = Global.last_save_recovered
	var directory := "user://backup_recovery_tests/"
	var primary := directory.path_join("file72")
	DirAccess.make_dir_recursive_absolute(directory)
	for suffix in ["", ".bak", ".tmp", ".invalid"]:
		if FileAccess.file_exists(primary + suffix): DirAccess.remove_absolute(primary + suffix)
	Global.player_set_hp(10)
	check(Global.storage_save(directory, 72), "first save is written")
	Global.player_set_hp(14)
	check(Global.storage_save(directory, 72) and FileAccess.file_exists(primary + ".bak"), "overwriting a save keeps the previous version as backup")
	Global.player_set_hp(5)
	check(Global.storage_load(directory, 72) and Global.player_data.hp == 14 and not Global.last_save_recovered, "valid primary save is preferred")
	var file := FileAccess.open(primary, FileAccess.WRITE)
	file.store_32(4096)
	file.close()
	var recoveries := [0]
	var on_recovered := func(slot: int):
		if slot == 72: recoveries[0] += 1
	Global.save_recovered.connect(on_recovered)
	check(Global.storage_load(directory, 72) and Global.player_data.hp == 10 and Global.last_save_recovered and recoveries[0] == 1, "truncated primary recovers the previous save and emits a signal")
	DirAccess.remove_absolute(primary)
	check(Global.storage_has_save(directory, 72) and Global.storage_load(directory, 72) and Global.player_data.hp == 10, "backup can be loaded if replacement was interrupted before the primary appeared")
	var temporary := FileAccess.open(primary + ".tmp", FileAccess.WRITE)
	temporary.store_32(4096)
	temporary.close()
	Global.player_set_hp(15)
	check(Global.storage_save(directory, 72), "a later save replaces an interrupted temporary file")
	Global.player_set_hp(5)
	check(Global.storage_load(directory, 72) and Global.player_data.hp == 15, "new primary remains readable after interrupted write")
	file = FileAccess.open(primary, FileAccess.WRITE)
	file.store_32(4096)
	file.close()
	Global.player_set_hp(16)
	check(Global.storage_save(directory, 72), "saving over a corrupt primary succeeds")
	file = FileAccess.open(primary, FileAccess.WRITE)
	file.store_32(4096)
	file.close()
	check(Global.storage_load(directory, 72) and Global.player_data.hp == 10, "saving over a corrupt primary preserves its valid backup")
	file = FileAccess.open(primary, FileAccess.WRITE)
	file.store_var({"version": 99, "player": {"hp": 18, "items": ["PROMISE"]}})
	file.close()
	Global.player_set_hp(16)
	check(not Global.storage_load(directory, 72) and Global.player_data.hp == 16, "an unknown primary version is not silently downgraded to its backup")
	check(not Global.storage_save(directory, 72), "a save from an unsupported version is not overwritten")
	file = FileAccess.open(primary, FileAccess.READ)
	var future_data: Dictionary = file.get_var()
	file.close()
	check(future_data.version == 99, "unsupported save data remains unchanged")
	DirAccess.remove_absolute(primary)
	file = FileAccess.open(primary + ".bak", FileAccess.WRITE)
	file.store_var({"version": 99, "player": {"hp": 18, "items": ["PROMISE"]}})
	file.close()
	check(not Global.storage_save(directory, 72), "an unsupported backup blocks saving when the primary is missing")
	check(not FileAccess.file_exists(primary), "an unsupported backup does not get shadowed by a new primary")
	file = FileAccess.open(primary, FileAccess.WRITE)
	file.store_var({"version": 1, "player": Global.player_data, "world": Global.world_state})
	file.close()
	check(not Global.storage_save(directory, 72), "an unsupported backup cannot be overwritten by primary rotation")
	file = FileAccess.open(primary + ".bak", FileAccess.READ)
	future_data = file.get_var()
	file.close()
	check(future_data.version == 99, "unsupported backup remains unchanged")
	DirAccess.remove_absolute(primary + ".bak")
	file = FileAccess.open(primary, FileAccess.WRITE)
	file.store_var({"hp": 11, "items": []})
	file.close()
	check(Global.storage_save(directory, 72), "a legacy player-only save can be backed up")
	file = FileAccess.open(primary, FileAccess.WRITE)
	file.store_32(4096)
	file.close()
	check(Global.storage_load(directory, 72) and Global.player_data.hp == 11, "a backed-up legacy player-only save remains recoverable")
	Global.save_recovered.disconnect(on_recovered)
	for suffix in ["", ".bak", ".tmp", ".invalid"]:
		if FileAccess.file_exists(primary + suffix): DirAccess.remove_absolute(primary + suffix)
	DirAccess.remove_absolute(directory)
	Global.world_state = old_world
	Global.current_save_slot = old_slot
	Global.last_save_recovered = old_recovered
	restore_player(old_player)
	await get_tree().process_frame


func test_world_save_restore() -> void:
	var previous_world: Dictionary = Global.world_state.duplicate(true)
	var previous_player: Dictionary = Global.player_data.duplicate(true)
	var tree := get_tree()
	var runner := tree.current_scene
	var world: Node2D = preload("res://overworld/test_level/test.tscn").instantiate()
	tree.root.add_child(world)
	tree.current_scene = world
	var player: OverworldFrisk = world.get_node("OverworldFrisk")
	await physical_key(KEY_C)
	check(WorldMenu.busy, "C opens the world menu through its actual key binding")
	await action_event("ui_down")
	await action_event("ui_accept")
	check(WorldMenu.state == "stats" and not player.movement_enabled, "world menu opens and displays player stats")
	await action_event("ui_cancel")
	await action_event("ui_cancel")
	check(not WorldMenu.busy and player.movement_enabled, "closing the world menu restores player control")
	ShopService.open_shop(["monster_candy"])
	await tree.process_frame
	await action_event("ui_accept")
	check(ShopService.state == "buy", "shop opens its buy menu from input")
	await action_event("ui_cancel")
	await action_event("ui_cancel")
	check(not ShopService.busy and player.movement_enabled, "closing the shop restores player control")
	var initial_slot: int = Global.current_save_slot
	Global.current_save_slot = 0
	var save_point: WorldInteractable = world.get_node("SavePoint")
	save_point.interact(player)
	await tree.process_frame
	DialogueService.typer.skip()
	await action_event("ui_right")
	await action_event("ui_right")
	await action_event("ui_accept")
	DialogueService.typer.skip()
	await action_event("ui_right")
	await action_event("ui_accept")
	check(Global.current_save_slot == 1, "save point allows choosing a slot")
	DialogueService.typer.skip()
	await action_event("ui_right")
	await action_event("ui_right")
	await action_event("ui_right")
	await action_event("ui_accept")
	check(not DialogueService.busy and player.movement_enabled, "closing the save menu restores player control")
	Global.current_save_slot = initial_slot
	player.global_position = Vector2(150, 175)
	Global.set_flag("saved_event", 42)
	var dir := "user://extended_tests/"
	check(Global.storage_save(dir, 42), "save writes the world and player data")
	Global.set_flag("saved_event", 0)
	player.global_position = Vector2(200, 200)
	var door: WorldInteractable = world.get_node("Door")
	door.interact(player)
	await EventService.event_finished
	check(tree.current_scene.scene_file_path.ends_with("side_room.tscn"), "door events switch to the target room")
	var side_players := tree.get_nodes_in_group("overworld_player")
	check(not side_players.is_empty() and side_players[0].global_position == Vector2(320, 300), "door events place the player at the destination")
	check(not side_players.is_empty() and side_players[0].movement_enabled, "door events restore control to the new player")
	var restored: bool = await Global.restore_world(dir, 42)
	var new_players := tree.get_nodes_in_group("overworld_player")
	check(restored and Global.get_flag("saved_event") == 42, "loading restores the saved flag")
	check(not new_players.is_empty() and new_players[0].global_position == Vector2(150, 175), "loading restores the saved room and position")
	for suffix in ["", ".bak", ".tmp", ".invalid"]:
		if FileAccess.file_exists(dir.path_join("file43" + suffix)): DirAccess.remove_absolute(dir.path_join("file43" + suffix))
	Global.set_flag("backup_room", "previous")
	check(Global.storage_save(dir, 43), "world save for backup recovery is written")
	Global.set_flag("backup_room", "latest")
	check(Global.storage_save(dir, 43), "world save creates a previous backup")
	var bad_room := FileAccess.open(dir.path_join("file43"), FileAccess.WRITE)
	bad_room.store_var({"version": 1, "player": Global.player_data, "world": {"flags": {}, "scene": "res://missing_room.tscn", "position": Vector2.ZERO}})
	bad_room.close()
	DialogueService.load_save_with_feedback(dir, 43)
	await Global.save_recovered
	await tree.process_frame
	check(Global.last_save_recovered and Global.get_flag("backup_room") == "previous", "room backup restores its own flags and reports recovery")
	check(DialogueService.busy, "recovery message survives the old room being freed")
	DialogueService.typer.skip()
	await action_event("ui_accept")
	check(not DialogueService.busy, "recovery message can be dismissed")
	check(Global.storage_save(dir, 43), "saving after recovering a missing room succeeds")
	bad_room = FileAccess.open(dir.path_join("file43"), FileAccess.WRITE)
	bad_room.store_32(4096)
	bad_room.close()
	var second_recovery := await Global.restore_world(dir, 43)
	check(second_recovery and Global.get_flag("backup_room") == "previous", "saving after missing-room recovery preserves the last usable backup")
	for suffix in ["", ".bak", ".tmp", ".invalid"]:
		if FileAccess.file_exists(dir.path_join("file43" + suffix)): DirAccess.remove_absolute(dir.path_join("file43" + suffix))
	var old_slot: int = Global.current_save_slot
	var unused_slot := 100000
	while FileAccess.file_exists("user://saves/file" + str(unused_slot)): unused_slot += 1
	Global.current_save_slot = unused_slot
	var outcome := [""]
	EncounterManager.battle_finished.connect(func(result): outcome[0] = result, CONNECT_ONE_SHOT)
	Global.player_set_hp(0)
	EncounterManager.encounter(-1, false)
	for frame in range(3): await tree.process_frame
	EncounterManager.finish_battle("lost")
	for frame in range(3): await tree.process_frame
	check(DialogueService.busy and outcome[0].is_empty(), "game over completes before the encounter result is emitted")
	DialogueService.typer.skip()
	await action_event("ui_accept")
	for frame in range(2): await tree.process_frame
	check(outcome[0] == "lost" and Global.player_data.hp == Global.player_data.hp_max, "continuing from game over restores HP and reports the loss")
	Global.current_save_slot = old_slot
	var restored_scene := tree.current_scene
	tree.current_scene = runner
	tree.root.remove_child(restored_scene)
	restored_scene.queue_free()
	for suffix in ["", ".bak", ".tmp", ".invalid"]:
		if FileAccess.file_exists(dir.path_join("file42" + suffix)): DirAccess.remove_absolute(dir.path_join("file42" + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	Global.world_state = previous_world
	restore_player(previous_player)
	await tree.process_frame


func test_custom_enemy_template() -> void:
	var saved_player: Dictionary = Global.player_data.duplicate(true)
	var old_encounter_id: int = EncounterManager.current_id
	var old_battle_soul: BattleSoulRed = EncounterManager.battle_soul
	var encounter_id := -int(Time.get_ticks_usec())
	var example := preload("res://examples/custom_enemy/guide_enemy.tscn")
	EncounterManager.encounter_set(encounter_id, example)
	EncounterManager.current_id = encounter_id
	var battle: Battle = preload("res://battle/Battle.tscn").instantiate()
	battle.box_transition_duration = 0.0
	battle.turn_duration = 1.0
	add_child(battle)
	await get_tree().process_frame
	check(battle.battle_get_enemy_count() == 1, "custom enemy scene loads into a registered encounter")
	var enemy: BattleEnemy = battle.battle_get_enemy(0)
	check(enemy.get_enemy_name() == "Guide" and enemy.get_hp_max() == 45.0 and enemy.data.gold_reward == 18, "custom enemy reads its configured data")
	check(enemy.action_get_name(1) == "Encourage", "custom enemy exposes its ACT callback")
	enemy.perform_action(1)
	check(not enemy.spareable, "one encouragement does not immediately allow sparing")
	enemy.perform_action(1)
	check(enemy.spareable, "a second encouragement allows sparing")
	for fps in [30, 60, 144]:
		for variant in ["bones", "pellets"]:
			battle.start_enemy_turn()
			check(battle.active_waves.size() == 1, "custom enemy starts exactly one wave")
			var wave: BattleWave = battle.active_waves[0]
			check(wave.scene_file_path.ends_with(variant + "_wave.tscn"), "custom enemy alternates to the %s wave" % variant)
			wave.set_physics_process(false)
			for frame in range(fps + 1):
				if wave.is_queued_for_deletion(): break
				wave._physics_process(1.0 / fps)
			check(wave.get("spawn_index") == 2, "%s wave schedules both attacks at %d updates/s" % [variant, fps])
			check(battle.battle_state == Battle.BATTLE_STATE.MENU and battle.active_waves.is_empty(), "the completed wave returns control to the battle menu")
			await get_tree().process_frame
			check(battle.bullets.get_child_count() == 0, "the battle cleans up the example wave's bullets")
	battle.start_enemy_turn()
	var long_step_wave: BattleWave = battle.active_waves[0]
	long_step_wave.set_physics_process(false)
	long_step_wave._physics_process(0.9)
	check(long_step_wave.get("spawn_index") == 2, "a long update does not skip example wave attacks")
	long_step_wave._physics_process(0.1)
	await get_tree().process_frame
	var old_gold := int(Global.player_data.gold)
	var old_exp := int(Global.player_data.exp)
	battle.mercy_choice = 0
	battle._resolve_mercy()
	check(battle.battle_get_enemy_count() == 0 and battle.reward_gold == 18 and battle.reward_exp == 0, "sparing the example enemy records gold but no EXP")
	battle._reward_message("*")
	battle._reward_message("*")
	check(int(Global.player_data.gold) == old_gold + 18 and int(Global.player_data.exp) == old_exp, "example encounter rewards are granted exactly once")
	battle.queue_free()
	await get_tree().process_frame
	EncounterManager.current_id = old_encounter_id
	EncounterManager.encounters.erase(encounter_id)
	EncounterManager.encounter_texts.erase(encounter_id)
	EncounterManager.battle_soul = old_battle_soul if is_instance_valid(old_battle_soul) else null
	restore_player(saved_player)
