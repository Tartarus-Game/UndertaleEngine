class_name Battle extends Node

@onready var box_typer: TextTyper = $BoxTyper
@onready var battle_box = $BattleBox

@export var items: BattleItemManager
@export var enemy_actions: BattleEnemyActions
@export var enemy_selections: BattleEnemySelections
@export var UImanager: BattleUIManager
@export var enemy_manager: EnemyManager
@export var soul: BattleSoulRed
@export_range(0.1, 120.0, 0.1) var turn_duration: float = 6.0 # seconds
@export_range(0.05, 10.0, 0.05) var bullet_interval: float = 0.55 # seconds
@export_range(0.0, 2.0, 0.05) var box_transition_duration: float = 0.25
@export var graze_enabled := false:
	set(value):
		graze_enabled = value
		if is_node_ready():
			soul.graze_enabled = value
			tp_changed.emit(tp_value, tp_max)
@export_range(1, 10000, 1) var tp_max := 100
@export_range(1, 1000, 1) var tp_per_graze := 1
@export var wave_scene: PackedScene = preload("res://battle/waves/ExampleWave.tscn")

const BULLET_SCENE = preload("res://battle/bullets/BattleBullet.tscn")
const MENU_BOX_SIZE = Vector2(573, 140)
const TURN_BOX_SIZE = Vector2(250, 140)

enum EVENT_TYPE {
	MENU_CHANGED, BUTTON_CHANGED, FIGHT_ENEMY_CHOICE_CHANGED,
	ACT_ENEMY_CHOICE_CHANGED, ACT_CHOICE_CHANGED, ITEM_CHOICE_CHANGED
}
enum BATTLE_MENU {
	BUTTON, FIGHT_ENEMY_CHOICE, FIGHT_AIM, FIGHT_ANIM,
	ACT_ENEMY_CHOICE, ACT_CHOICE, ITEM, MERCY, ITEM_COMMAND, ITEM_INFO
}
enum BATTLE_STATE { MENU, MESSAGE, ENEMY_TURN, RESULT, TRANSITION }

signal BattleEvent(TYPE: EVENT_TYPE, EVENT: Variant, FORM: Variant)
signal turn_started(turn_number: int)
signal turn_finished(turn_number: int)
signal tp_changed(value: int, maximum: int)

var battle_menu: BATTLE_MENU = BATTLE_MENU.BUTTON
var _last_menu: BATTLE_MENU = BATTLE_MENU.BUTTON
var battle_state: BATTLE_STATE = BATTLE_STATE.MENU
var battle_fight_enemy_choice := 0
var battle_act_enemy_choice := 0
var battle_act_choice := 0
var battle_item_choice := 0
var battle_item_page := 0
var battle_item_command := 0
var battle_menu_button := 0
var mercy_choice := 0
var turn_number := 0
var active_wave: BattleWave
var active_waves: Array[BattleWave] = []
var reward_exp := 0
var reward_gold := 0
var rewards_granted := false
var tp_value := 0
var _message_next := ""
var _result := ""
var _turn_dialogues: Array[String] = []
var _await_accept_release := true
var fight_meter: FightMeter
var bullets: Node2D
var effects: Node2D
var bullet_clip: Control
var arena_mask: ColorRect


func _ready() -> void:
	fight_meter = FightMeter.new()
	fight_meter.position = Vector2(320, 320)
	fight_meter.z_index = 2
	fight_meter.visible = false
	add_child(fight_meter)
	fight_meter.missed.connect(_on_fight_missed)
	bullet_clip = Control.new()
	bullet_clip.clip_contents = true
	bullet_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bullet_clip.z_index = 2
	add_child(bullet_clip)
	bullets = Node2D.new()
	bullet_clip.add_child(bullets)
	effects = Node2D.new()
	effects.z_index = 2
	add_child(effects)
	arena_mask = ColorRect.new()
	arena_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_mask.z_index = 3
	arena_mask.visible = false
	var mask_shader := Shader.new()
	mask_shader.code = "shader_type canvas_item; uniform int count = 0; uniform vec2 points[32]; uniform vec2 origin; uniform vec2 extent; void fragment() { vec2 p = origin + UV * extent; bool inside = false; for (int i = 0; i < 32; i++) { if (i >= count) break; int j = (i + count - 1) % count; vec2 a = points[i]; vec2 b = points[j]; if (((a.y > p.y) != (b.y > p.y)) && (p.x < (b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x)) inside = !inside; } COLOR = inside ? vec4(0.0) : vec4(0.0,0.0,0.0,1.0); }"
	var mask_material := ShaderMaterial.new()
	mask_material.shader = mask_shader
	arena_mask.material = mask_material
	add_child(arena_mask)
	soul.z_index = 4
	soul.defeated.connect(_on_soul_defeated)
	soul.shot_requested.connect(_on_soul_shot)
	soul.graze_enabled = graze_enabled
	soul.grazed.connect(_on_soul_grazed)
	tp_changed.emit(tp_value, tp_max)
	EncounterManager.battle_soul = soul
	battle_set_button(0)
	battle_set_menu(BATTLE_MENU.BUTTON)
	var intro := EncounterManager.get_current_encounter_text()
	_set_prompt(intro if not intro.is_empty() else SettingsService.text("battle.choose"))


func battle_set_fight_enemy_choice(slot: int) -> void:
	if battle_get_enemy_count() == 0: return
	battle_fight_enemy_choice = clampi(slot, 0, battle_get_enemy_count() - 1)
	enemy_selections.hide_info(false)
	enemy_selections.set_slot(battle_fight_enemy_choice)
	soul.position = enemy_selections.selections[battle_fight_enemy_choice].position
	BattleEvent.emit(EVENT_TYPE.FIGHT_ENEMY_CHOICE_CHANGED, battle_fight_enemy_choice, -1)


func battle_set_act_enemy_choice(slot: int) -> void:
	if battle_get_enemy_count() == 0: return
	battle_act_enemy_choice = clampi(slot, 0, battle_get_enemy_count() - 1)
	enemy_selections.hide_info(true)
	enemy_selections.set_slot(battle_act_enemy_choice)
	soul.position = enemy_selections.selections[battle_act_enemy_choice].position
	BattleEvent.emit(EVENT_TYPE.ACT_ENEMY_CHOICE_CHANGED, battle_act_enemy_choice, -1)


func battle_set_act_choice(slot: int) -> void:
	var enemy := battle_get_act_enemy_choice()
	if enemy == null or enemy.action_get_count() == 0: return
	battle_act_choice = clampi(slot, 0, enemy.action_get_count() - 1)
	var page_size := enemy_actions.selections.size()
	var page_start := floori(float(battle_act_choice) / float(page_size)) * page_size
	var actions: Array[String] = enemy.get_actions().slice(page_start, page_start + page_size)
	enemy_actions.set_actions_name(actions)
	soul.position = enemy_actions.selections[battle_act_choice % page_size].position - Vector2(36, 0)
	BattleEvent.emit(EVENT_TYPE.ACT_CHOICE_CHANGED, battle_act_choice, -1)


func battle_set_item_choice(slot: int) -> void:
	var count: int = Global.player_get_item_count()
	if count == 0: return
	battle_item_choice = clampi(slot, 0, count - 1)
	battle_item_page = clampi(battle_item_page, maxi(0, battle_item_choice - 2), battle_item_choice)
	items.set_slot(battle_item_choice)
	soul.position = Vector2(85, 288 + 32 * (battle_item_choice - battle_item_page))
	BattleEvent.emit(EVENT_TYPE.ITEM_CHOICE_CHANGED, battle_item_choice, -1)


func battle_get_fight_enemy_choice() -> BattleEnemy:
	return battle_get_enemy(battle_fight_enemy_choice)

func battle_get_act_enemy_choice() -> BattleEnemy:
	return battle_get_enemy(battle_act_enemy_choice)

func battle_get_act_choice_number() -> int:
	return battle_act_choice

func battle_set_button(slot: int) -> void:
	battle_menu_button = posmod(slot, 4)
	UImanager.get_ui().sync_active_index(battle_menu_button)
	BattleEvent.emit(EVENT_TYPE.BUTTON_CHANGED, battle_menu_button, -1)

func choose_main_button(slot: int) -> void:
	match slot:
		0:
			if battle_get_enemy_count() > 0: battle_set_menu(BATTLE_MENU.FIGHT_ENEMY_CHOICE)
		1:
			if battle_get_enemy_count() > 0: battle_set_menu(BATTLE_MENU.ACT_ENEMY_CHOICE)
		2:
			if Global.player_get_item_count() > 0: battle_set_menu(BATTLE_MENU.ITEM)
		3: battle_set_menu(BATTLE_MENU.MERCY)


func _hide_choices() -> void:
	for i in range(enemy_selections.selections.size()):
		enemy_selections.hide_enemy(i, true)
	enemy_actions.hide_all_actions(true)
	items.hide_all(true)


func battle_set_menu(menu: BATTLE_MENU) -> void:
	battle_menu = menu
	_hide_choices()
	box_typer.visible = menu == BATTLE_MENU.BUTTON or menu == BATTLE_MENU.ITEM_INFO
	soul.visible = menu != BATTLE_MENU.FIGHT_AIM and menu != BATTLE_MENU.ITEM_INFO
	match menu:
		BATTLE_MENU.FIGHT_ENEMY_CHOICE, BATTLE_MENU.ACT_ENEMY_CHOICE:
			for i in range(mini(battle_get_enemy_count(), enemy_selections.selections.size())):
				var enemy := battle_get_enemy(i)
				enemy_selections.hide_enemy(i, false)
				enemy_selections.set_enemy_info(i, enemy.get_enemy_name(), enemy.get_hp(), enemy.get_hp_max(), enemy.spareable)
			if menu == BATTLE_MENU.FIGHT_ENEMY_CHOICE:
				battle_set_fight_enemy_choice(battle_fight_enemy_choice)
			else:
				battle_set_act_enemy_choice(battle_act_enemy_choice)
		BATTLE_MENU.ACT_CHOICE:
			battle_set_act_choice(0)
		BATTLE_MENU.ITEM:
			items.set_items(Global.player_get_items())
			if _last_menu != BATTLE_MENU.ITEM_COMMAND and _last_menu != BATTLE_MENU.ITEM_INFO:
				battle_item_choice = 0
				battle_item_page = 0
				items.page = 0
			battle_set_item_choice(battle_item_choice)
		BATTLE_MENU.ITEM_COMMAND:
			var commands: Array[String] = [SettingsService.text("item.use"), SettingsService.text("item.info"), SettingsService.text("item.drop")]
			enemy_actions.set_actions_name(commands)
			_set_item_command(0)
		BATTLE_MENU.ITEM_INFO:
			var item = ItemManager.item_get(Global.player_get_item(battle_item_choice))
			_set_prompt(item.info() if item else "* Unknown item.")
		BATTLE_MENU.MERCY:
			var choices: Array[String] = [SettingsService.text("battle.spare"), SettingsService.text("battle.flee")]
			enemy_actions.set_actions_name(choices)
			_set_mercy_choice(0)
		BATTLE_MENU.FIGHT_AIM:
			fight_meter.start()
	BattleEvent.emit(EVENT_TYPE.MENU_CHANGED, menu, _last_menu)
	_last_menu = menu


func _set_mercy_choice(slot: int) -> void:
	mercy_choice = clampi(slot, 0, 1)
	soul.position = enemy_actions.selections[mercy_choice].position - Vector2(36, 0)

func _set_item_command(slot: int) -> void:
	battle_item_command = clampi(slot, 0, 2)
	soul.position = enemy_actions.selections[battle_item_command].position - Vector2(36, 0)

func battle_get_menu(): return battle_menu
func battle_get_state(): return battle_state
func battle_get_enemy(slot: int) -> BattleEnemy: return enemy_manager.battle_get_enemy(slot)
func battle_get_enemys(): return enemy_manager.battle_get_enemys()
func battle_get_enemy_count(): return enemy_manager.battle_get_enemy_count()
func battle_set_enemy(slot: int, packed: PackedScene): return enemy_manager.battle_set_enemy(slot, packed)


func _physics_process(_delta: float) -> void:
	if battle_state == BATTLE_STATE.ENEMY_TURN:
		_sync_arena()


func set_arena_polygon(points: PackedVector2Array) -> bool:
	if not battle_box.set_polygon(points): return false
	_sync_arena()
	return true


func _sync_arena() -> void:
	var points := PackedVector2Array()
	for point in battle_box.polygon:
		points.append(battle_box.to_global(point))
	soul.arena_polygon = points
	var bounds := Rect2(battle_box.global_position - battle_box.size / 2.0, battle_box.size)
	if not points.is_empty():
		bounds = Rect2(points[0], Vector2.ZERO)
		for point in points: bounds = bounds.expand(point)
	soul.arena = bounds
	bullet_clip.position = bounds.position
	bullet_clip.size = bounds.size
	bullets.position = -bounds.position
	arena_mask.visible = not points.is_empty()
	if not points.is_empty():
		arena_mask.position = bounds.position
		arena_mask.size = bounds.size
		var padded := points.duplicate()
		while padded.size() < 32: padded.append(Vector2.ZERO)
		var mat := arena_mask.material as ShaderMaterial
		mat.set_shader_parameter("count", points.size())
		mat.set_shader_parameter("points", padded)
		mat.set_shader_parameter("origin", bounds.position)
		mat.set_shader_parameter("extent", bounds.size)


func _process(_delta: float) -> void:
	# The key that triggered an encounter must be released before the battle
	# consumes input; otherwise one press also selects FIGHT in the new scene.
	if _await_accept_release:
		if not Input.is_action_pressed("ui_accept") and not Input.is_action_just_pressed("ui_accept"):
			_await_accept_release = false
		return
	if battle_state == BATTLE_STATE.MESSAGE or battle_state == BATTLE_STATE.RESULT:
		if Input.is_action_just_pressed("ui_down"):
			box_typer.get_v_scroll_bar().value += 32.0
		elif Input.is_action_just_pressed("ui_up"):
			box_typer.get_v_scroll_bar().value -= 32.0
		elif Input.is_action_just_pressed("ui_accept"):
			if box_typer.pause:
				box_typer.resume_text()
			elif box_typer.is_typing():
				box_typer.skip()
			elif battle_state == BATTLE_STATE.RESULT:
				EncounterManager.finish_battle(_result)
			else:
				_continue_after_message()
		return
	if battle_state != BATTLE_STATE.MENU: return

	match battle_menu:
		BATTLE_MENU.BUTTON:
			soul.position = UImanager.get_ui().get_button(battle_menu_button).global_position + Vector2(-38, 0)
			if Input.is_action_just_pressed("ui_right"): UImanager.get_ui().navigate(1)
			elif Input.is_action_just_pressed("ui_left"): UImanager.get_ui().navigate(-1)
			elif Input.is_action_just_pressed("ui_accept"): UImanager.get_ui().click_active()
		BATTLE_MENU.FIGHT_ENEMY_CHOICE:
			if Input.is_action_just_pressed("ui_down"): battle_set_fight_enemy_choice(battle_fight_enemy_choice + 1)
			elif Input.is_action_just_pressed("ui_up"): battle_set_fight_enemy_choice(battle_fight_enemy_choice - 1)
			elif Input.is_action_just_pressed("ui_accept"): battle_set_menu(BATTLE_MENU.FIGHT_AIM)
			elif Input.is_action_just_pressed("ui_cancel"): battle_set_menu(BATTLE_MENU.BUTTON)
		BATTLE_MENU.FIGHT_AIM:
			if Input.is_action_just_pressed("ui_accept"): _resolve_fight(fight_meter.accuracy())
		BATTLE_MENU.ACT_ENEMY_CHOICE:
			if Input.is_action_just_pressed("ui_down"): battle_set_act_enemy_choice(battle_act_enemy_choice + 1)
			elif Input.is_action_just_pressed("ui_up"): battle_set_act_enemy_choice(battle_act_enemy_choice - 1)
			elif Input.is_action_just_pressed("ui_accept"): battle_set_menu(BATTLE_MENU.ACT_CHOICE)
			elif Input.is_action_just_pressed("ui_cancel"): battle_set_menu(BATTLE_MENU.BUTTON)
		BATTLE_MENU.ACT_CHOICE:
			if Input.is_action_just_pressed("ui_right") and battle_act_choice % 2 == 0: battle_set_act_choice(battle_act_choice + 1)
			elif Input.is_action_just_pressed("ui_left") and battle_act_choice % 2 == 1: battle_set_act_choice(battle_act_choice - 1)
			elif Input.is_action_just_pressed("ui_up") and battle_act_choice >= 2: battle_set_act_choice(battle_act_choice - 2)
			elif Input.is_action_just_pressed("ui_down") and battle_act_choice + 2 < battle_get_act_enemy_choice().action_get_count(): battle_set_act_choice(battle_act_choice + 2)
			elif Input.is_action_just_pressed("ui_accept"):
				_show_message(battle_get_act_enemy_choice().perform_action(battle_act_choice), "turn")
			elif Input.is_action_just_pressed("ui_cancel"): battle_set_menu(BATTLE_MENU.ACT_ENEMY_CHOICE)
		BATTLE_MENU.ITEM:
			if Input.is_action_just_pressed("ui_up"): battle_set_item_choice(battle_item_choice - 1)
			elif Input.is_action_just_pressed("ui_down"): battle_set_item_choice(battle_item_choice + 1)
			elif Input.is_action_just_pressed("ui_accept"): battle_set_menu(BATTLE_MENU.ITEM_COMMAND)
			elif Input.is_action_just_pressed("ui_cancel"): battle_set_menu(BATTLE_MENU.BUTTON)
		BATTLE_MENU.ITEM_COMMAND:
			if Input.is_action_just_pressed("ui_right") and battle_item_command == 0: _set_item_command(1)
			elif Input.is_action_just_pressed("ui_left") and battle_item_command == 1: _set_item_command(0)
			elif Input.is_action_just_pressed("ui_down") and battle_item_command == 0: _set_item_command(2)
			elif Input.is_action_just_pressed("ui_up") and battle_item_command == 2: _set_item_command(0)
			elif Input.is_action_just_pressed("ui_cancel"): battle_set_menu(BATTLE_MENU.ITEM)
			elif Input.is_action_just_pressed("ui_accept"):
				match battle_item_command:
					0: _use_item()
					1: battle_set_menu(BATTLE_MENU.ITEM_INFO)
					2: _drop_item()
		BATTLE_MENU.ITEM_INFO:
			if Input.is_action_just_pressed("ui_down"): box_typer.get_v_scroll_bar().value += 32.0
			elif Input.is_action_just_pressed("ui_up"): box_typer.get_v_scroll_bar().value -= 32.0
			elif Input.is_action_just_pressed("ui_accept"):
				if box_typer.is_typing(): box_typer.skip()
				else: battle_set_menu(BATTLE_MENU.ITEM_COMMAND)
			elif Input.is_action_just_pressed("ui_cancel"): battle_set_menu(BATTLE_MENU.ITEM_COMMAND)
		BATTLE_MENU.MERCY:
			if Input.is_action_just_pressed("ui_left"): _set_mercy_choice(0)
			elif Input.is_action_just_pressed("ui_right"): _set_mercy_choice(1)
			elif Input.is_action_just_pressed("ui_accept"): _resolve_mercy()
			elif Input.is_action_just_pressed("ui_cancel"): battle_set_menu(BATTLE_MENU.BUTTON)


func _set_prompt(message: String) -> void:
	box_typer.clear_text()
	box_typer.text_add_markup(message)
	box_typer.next_text()
	box_typer.get_v_scroll_bar().value = 0.0


func _show_message(message: String, next: String) -> void:
	battle_state = BATTLE_STATE.MESSAGE
	_message_next = next
	_hide_choices()
	soul.visible = false
	box_typer.visible = true
	_set_prompt(message)


func _continue_after_message() -> void:
	if _message_next == "turn":
		_turn_dialogues.clear()
		for enemy in battle_get_enemys():
			var dialogue := enemy.get_turn_dialog()
			if not dialogue.is_empty(): _turn_dialogues.append(dialogue)
		_advance_turn_dialogue()
	elif _message_next == "turn_dialogue":
		_advance_turn_dialogue()
	elif _message_next == "win":
		_show_result("won", _reward_message(SettingsService.text("battle.won")))
	elif _message_next == "flee":
		_show_result("fled", _reward_message(SettingsService.text("battle.fled")))


func _reward_message(prefix: String) -> String:
	if not rewards_granted:
		rewards_granted = true
		var leveled := Global.award_rewards(reward_exp, reward_gold)
		if leveled:
			prefix += "\n" + SettingsService.text("battle.level_up")
	return prefix + "\n" + SettingsService.text("battle.reward") % [reward_exp, reward_gold]


func _advance_turn_dialogue() -> void:
	if _turn_dialogues.is_empty():
		start_enemy_turn()
	else:
		_show_message(_turn_dialogues.pop_front(), "turn_dialogue")


func _resolve_fight(accuracy: float) -> void:
	fight_meter.running = false
	fight_meter.visible = false
	var enemy := battle_get_fight_enemy_choice()
	if enemy == null: return
	var before: float = enemy.get_hp()
	if accuracy > 0.0:
		var slash := DamageSlash.new()
		slash.position = enemy.position
		slash.z_index = 4
		add_child(slash)
	var damage := roundi(enemy.take_damage(accuracy * Global.player_get_attack()))
	var display := EnemyDamageDisplay.new()
	display.position = enemy.position
	display.z_index = 4
	display.setup(damage, before, enemy.get_hp(), enemy.get_hp_max(), enemy.choice_box_size.x)
	add_child(display)
	var message := SettingsService.text("battle.damage") % [enemy.get_enemy_name(), damage]
	if enemy.get_hp() <= 0:
		reward_exp += enemy.data.exp_reward
		reward_gold += enemy.data.gold_reward
		enemy_manager.battle_remove_enemy(enemy)
	_show_message(message, "win" if battle_get_enemy_count() == 0 else "turn")


func _on_fight_missed() -> void:
	_resolve_fight(0.0)


func _use_item() -> void:
	var id: String = Global.player_get_item(battle_item_choice)
	var item = ItemManager.item_get(id)
	if item: item._slot = battle_item_choice
	var message: String = item.use() if item else "* This item has no effect."
	if item and item.consumable:
		Global.remove_item(battle_item_choice)
	_show_message(message, "turn")


func _drop_item() -> void:
	var id: String = Global.player_get_item(battle_item_choice)
	var item = ItemManager.item_get(id)
	var message: String = item.drop() if item else "* You dropped the item."
	if not item or item.droppable:
		Global.remove_item(battle_item_choice)
	_show_message(message, "turn")


func _resolve_mercy() -> void:
	if mercy_choice == 1:
		var chance := 1.0
		for enemy in battle_get_enemys():
			if not enemy.get_can_flee():
				_show_message(SettingsService.text("battle.no_escape"), "turn")
				return
			chance = minf(chance, enemy.get_flee_chance(turn_number))
		if chance <= 0.0 or (chance < 1.0 and randf() >= chance):
			_show_message(SettingsService.text("battle.failed_escape"), "turn")
			return
		_show_message(SettingsService.text("battle.ran"), "flee")
		return
	var spared := 0
	for enemy in battle_get_enemys().duplicate():
		if enemy.spareable:
			reward_gold += enemy.data.gold_reward
			enemy_manager.battle_remove_enemy(enemy)
			spared += 1
	var message := SettingsService.text("battle.spared") % spared if spared > 0 else SettingsService.text("battle.no_spare")
	_show_message(message, "win" if battle_get_enemy_count() == 0 else "turn")


func start_enemy_turn() -> void:
	battle_state = BATTLE_STATE.TRANSITION
	turn_number += 1
	box_typer.visible = false
	soul.visible = false
	if box_transition_duration > 0.0:
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(battle_box, "size", TURN_BOX_SIZE, box_transition_duration)
		await tween.finished
	else:
		battle_box.size = TURN_BOX_SIZE
	battle_state = BATTLE_STATE.ENEMY_TURN
	_sync_arena()
	soul.global_position = battle_box.global_position
	soul.movement_enabled = true
	soul.visible = true
	active_waves.clear()
	for enemy in battle_get_enemys():
		var custom_wave := enemy.get_wave_scene(turn_number)
		if custom_wave:
			_start_wave(custom_wave, enemy)
	if active_waves.is_empty():
		_start_wave(wave_scene, null)
	active_wave = active_waves[0] if not active_waves.is_empty() else null
	if active_wave == null:
		end_enemy_turn()
		return
	turn_started.emit(turn_number)


func _start_wave(scene: PackedScene, owner_enemy: BattleEnemy) -> void:
	if scene == null:
		return
	var wave := scene.instantiate() as BattleWave
	if wave == null:
		return
	wave.battle = self
	wave.source_enemy = owner_enemy
	wave.duration = turn_duration
	if wave is ExampleWave:
		wave.interval = bullet_interval
	active_waves.append(wave)
	wave.finished.connect(_on_wave_finished.bind(wave))
	add_child(wave)


func _on_wave_finished(wave: BattleWave) -> void:
	active_waves.erase(wave)
	wave.queue_free()
	if active_waves.is_empty():
		end_enemy_turn()
	else:
		active_wave = active_waves[0]


func _clear_waves() -> void:
	for wave in active_waves:
		if is_instance_valid(wave):
			wave.queue_free()
	active_waves.clear()
	active_wave = null


func spawn_bullet(bullet: BattleBullet, at: Vector2, show_outside := false) -> void:
	bullet.position = at
	if show_outside:
		effects.add_child(bullet)
	else:
		bullets.add_child(bullet)


func _on_soul_shot(origin: Vector2, direction: Vector2) -> void:
	var shot := SoulProjectile.new()
	shot.position = origin
	shot.velocity = direction.normalized() * 360.0
	shot.battle = self
	bullets.add_child(shot)


func _on_soul_grazed(_bullet: BattleBullet) -> void:
	set_tp(tp_value + tp_per_graze)


func set_tp(value: int) -> void:
	var next := clampi(value, 0, maxi(tp_max, 1))
	if tp_value == next: return
	tp_value = next
	tp_changed.emit(tp_value, tp_max)


func spend_tp(amount: int) -> bool:
	if amount < 0 or amount > tp_value: return false
	set_tp(tp_value - amount)
	return true


func damage_enemy_from_projectile(enemy: BattleEnemy, amount: float) -> void:
	if enemy not in battle_get_enemys(): return
	enemy.take_damage(amount)
	if enemy.get_hp() > 0: return
	reward_exp += enemy.data.exp_reward
	reward_gold += enemy.data.gold_reward
	enemy_manager.battle_remove_enemy(enemy)
	if battle_get_enemy_count() == 0:
		_clear_waves()
		_clear_bullets()
		soul.movement_enabled = false
		_reset_arena()
		battle_box.size = MENU_BOX_SIZE
		_show_message("* The enemy was defeated.", "win")


func end_enemy_turn() -> void:
	if battle_state != BATTLE_STATE.ENEMY_TURN: return
	battle_state = BATTLE_STATE.TRANSITION
	soul.movement_enabled = false
	soul.visible = false
	_reset_arena()
	_clear_waves()
	_clear_bullets()
	if box_transition_duration > 0.0:
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(battle_box, "size", MENU_BOX_SIZE, box_transition_duration)
		await tween.finished
	else:
		battle_box.size = MENU_BOX_SIZE
	battle_state = BATTLE_STATE.MENU
	turn_finished.emit(turn_number)
	battle_set_menu(BATTLE_MENU.BUTTON)
	var prompt := SettingsService.text("battle.choose")
	for enemy in battle_get_enemys():
		if not enemy.data.menu_messages.is_empty():
			prompt = enemy.data.menu_messages.pick_random()
			break
	_set_prompt(prompt)


func _reset_arena() -> void:
	soul.set_mode("red")
	battle_box.set_polygon(PackedVector2Array())
	soul.arena_polygon.clear()
	arena_mask.visible = false


func _clear_bullets() -> void:
	for bullet in bullets.get_children(): bullet.queue_free()
	for effect in effects.get_children(): effect.queue_free()


func _on_soul_defeated() -> void:
	_clear_waves()
	_clear_bullets()
	soul.movement_enabled = false
	_reset_arena()
	battle_box.size = MENU_BOX_SIZE
	_show_result("lost", SettingsService.text("battle.defeated"))


func _show_result(result: String, message: String) -> void:
	_result = result
	battle_state = BATTLE_STATE.RESULT
	_hide_choices()
	soul.visible = false
	box_typer.visible = true
	_set_prompt(message)
