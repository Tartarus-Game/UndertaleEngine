class_name Battle extends Node

@export var UImanager : BattleUIManager;
@export var enemy_manager : EnemyManager;
@export var soul : BattleSoulRed;

const BattleMenuSelectorClass = preload("res://battle/UI/BattleMenuSelector.gd")
const BattleDamageClass = preload("res://battle/UI/BattleDamage.tscn")
const ShakerClass = preload("res://battle/UI/Shaker.gd")

enum EVENT_TYPE{
	# 广播给 BattleUI 的事件类型。
	MENU_CHANGED,
	BUTTON_CHANGED,
	FIGHT_ENEMY_CHOICE_CHANGED,
	ACT_ENEMY_CHOICE_CHANGED,
	ACT_CHOICE_CHANGED,
	ITEM_CHOICE_CHANGED,
	MERCY_CHOICE_CHANGED
}

enum BATTLE_MENU{
	# 菜单层状态：底部四按钮、子菜单、攻击执行阶段。
	BUTTON,
	FIGHT_ENEMY_CHOICE,
	FIGHT_AIM,
	FIGHT_ANIM,
	FIGHT_DAMAGE,
	ACT_ENEMY_CHOICE,
	ACT_CHOICE,
	ITEM,
	MERCY
}
enum BATTLE_STATE{
	# 战斗大状态：菜单、文本、敌方回合、结算。
	MENU,
	DIALOG,
	TURN_PREPARATION,
	IN_TURN,
	BOARD_RESETTING,
	RESULT
}

signal BattleEvent(TYPE: EVENT_TYPE, EVENT: Variant, FORM: Variant);
# 当前菜单/状态以及上一状态，用于 UI 过渡和状态回溯。
var battle_menu : BATTLE_MENU = BATTLE_MENU.BUTTON;
var _last_menu : BATTLE_MENU = BATTLE_MENU.BUTTON;
var battle_state : BATTLE_STATE = BATTLE_STATE.MENU;
var _last_state : BATTLE_STATE = BATTLE_STATE.MENU;
var battle_fight_enemy_choice : int = 0;
var battle_act_enemy_choice : int = 0;
var battle_act_choice : int = 0;
var battle_item_choice : int = 0;
var battle_mercy_choice : int = 0;

var battle_menu_button : int = 0;
# 通用选择器：四按钮与各子菜单统一走这一份索引模型。
var _menu_selector = BattleMenuSelectorClass.new()

# FIGHT 执行阶段计时与最终伤害缓存。
var _fight_anim_time: int = -1
var _fight_damage_time: int = -1
var _current_damage: int = 0

func _clamp_choice(slot: int, size: int) -> int:
	# 把选项索引限制在合法范围内，避免数组越界。
	if size <= 0:
		return 0
	return clampi(slot, 0, size - 1)

func _wrap_button_slot(slot: int) -> int:
	# 四个主按钮使用循环切换：左越界回到 3，右越界回到 0。
	if slot < 0:
		return 3
	if slot > 3:
		return 0
	return slot

func _build_menu_selector_options(menu: BATTLE_MENU) -> Array:
	# 根据当前菜单类型，构建可选项列表，供通用 selector 使用。
	match menu:
		BATTLE_MENU.BUTTON:
			return [0, 1, 2, 3]
		BATTLE_MENU.FIGHT_ENEMY_CHOICE, BATTLE_MENU.ACT_ENEMY_CHOICE:
			var enemy_slots: Array = []
			for i in range(battle_get_enemy_count()):
				enemy_slots.append(i)
			return enemy_slots
		BATTLE_MENU.ACT_CHOICE:
			var action_slots: Array = []
			var enemy = battle_get_act_enemy_choice()
			if enemy == null:
				return action_slots
			for i in range(enemy.action_get_count()):
				action_slots.append(i)
			return action_slots
		BATTLE_MENU.ITEM:
			return Global.player_data_items.duplicate()
		BATTLE_MENU.MERCY:
			return ["Spare", "Flee"]
	return []

func _sync_selector_with_menu(keep_slot: bool = false):
	# 让 selector 的 options/slot 与当前 battle_menu 状态保持一致。
	_menu_selector.set_options(_build_menu_selector_options(battle_menu), keep_slot)
	match battle_menu:
		BATTLE_MENU.BUTTON:
			_menu_selector.set_slot(battle_menu_button)
		BATTLE_MENU.FIGHT_ENEMY_CHOICE:
			_menu_selector.set_slot(battle_fight_enemy_choice)
		BATTLE_MENU.ACT_ENEMY_CHOICE:
			_menu_selector.set_slot(battle_act_enemy_choice)
		BATTLE_MENU.ACT_CHOICE:
			_menu_selector.set_slot(battle_act_choice)
		BATTLE_MENU.ITEM:
			_menu_selector.set_slot(battle_item_choice)
		BATTLE_MENU.MERCY:
			_menu_selector.set_slot(battle_mercy_choice)

func _apply_selector_to_menu():
	# 把 selector 当前选中项回写到具体业务字段（按钮、敌人、物品等）。
	var selected_slot = _menu_selector.get_slot()
	match battle_menu:
		BATTLE_MENU.BUTTON:
			battle_set_button(selected_slot)
		BATTLE_MENU.FIGHT_ENEMY_CHOICE:
			battle_set_fight_enemy_choice(selected_slot)
		BATTLE_MENU.ACT_ENEMY_CHOICE:
			battle_set_act_enemy_choice(selected_slot)
		BATTLE_MENU.ACT_CHOICE:
			battle_set_act_choice(selected_slot)
		BATTLE_MENU.ITEM:
			battle_set_item_choice(selected_slot)
		BATTLE_MENU.MERCY:
			battle_set_mercy_choice(selected_slot)

func _menu_move(offset: int):
	# 统一处理菜单移动逻辑（左右/上下最终都走这里）。
	if _menu_selector.get_size() <= 0:
		return
	_menu_selector.move(offset)
	_apply_selector_to_menu()

func _do_act():
	# 执行 ACT：读取行动描述并进入 DIALOG，文本结束后推进到敌方回合准备。
	var enemy = battle_get_act_enemy_choice()
	if enemy == null:
		return
	var desc = enemy.action_get_desc(battle_act_choice)
	if desc == null:
		desc = "* You acted."
	
	battle_set_state(BATTLE_STATE.DIALOG)
	var ui = UImanager.get_ui()
	if ui and ui.menu_renderer:
		ui.menu_renderer.hide_menu()
		
	var typer = $TextTyper
	typer.clear_text()
	typer.texts.clear()
	typer.pause = false
	typer.text_add(desc, func(t): t.pause = true)
	typer.text_add("", func(t):
		t.clear_text()
		t.pause = false
		battle_set_state(BATTLE_STATE.TURN_PREPARATION)
	)
	typer.next_text()

func _use_selected_item():
	# 执行 ITEM：使用物品、从背包移除，并显示使用文本。
	if Global.player_data_items.is_empty():
		return
	battle_item_choice = _clamp_choice(battle_item_choice, Global.player_data_items.size())
	var selected_item = Global.player_data_items[battle_item_choice]
	var item_name = "item"
	if typeof(selected_item) == TYPE_OBJECT and selected_item.has_method("name"):
		var maybe_name = selected_item.name()
		if maybe_name != null:
			item_name = str(maybe_name)
	else:
		item_name = str(selected_item)
	
	if typeof(selected_item) == TYPE_OBJECT and selected_item.has_method("use"):
		selected_item.use()
	Global.player_data_items.remove_at(battle_item_choice)
	
	battle_set_state(BATTLE_STATE.DIALOG)
	var ui = UImanager.get_ui()
	if ui and ui.menu_renderer:
		ui.menu_renderer.hide_menu()
		
	var typer = $TextTyper
	typer.clear_text()
	typer.texts.clear()
	typer.pause = false
	typer.text_add("* You used the " + item_name + ".", func(t): t.pause = true)
	typer.text_add("", func(t):
		t.clear_text()
		t.pause = false
		battle_set_state(BATTLE_STATE.TURN_PREPARATION)
	)
	typer.next_text()

func _confirm_mercy_choice():
	# 执行 MERCY 确认入口，根据当前选择分发到 Spare/Flee。
	match battle_mercy_choice:
		0:
			_do_spare()
		1:
			_do_flee()

func _do_spare():
	# Spare：移除所有可饶恕敌人；若清场则进入 RESULT，否则继续战斗流程。
	var enemys = battle_get_enemys()
	var spared_any = false
	for i in range(len(enemys) - 1, -1, -1):
		var enemy = enemys[i]
		if enemy.get_spareable():
			battle_remove_enemy(i)
			spared_any = true
			
	if spared_any:
		if not battle_has_enemies():
			# All enemies spared! End battle placeholder
			battle_set_state(BATTLE_STATE.RESULT)
		else:
			battle_set_state(BATTLE_STATE.DIALOG)
			var ui = UImanager.get_ui()
			if ui and ui.menu_renderer:
				ui.menu_renderer.hide_menu()
			
			var typer = $TextTyper
			typer.clear_text()
			typer.texts.clear()
			typer.pause = false
			typer.text_add("* You spared the enemy.", func(t): t.pause = true)
			typer.text_add("", func(t):
				t.clear_text()
				t.pause = false
				battle_set_state(BATTLE_STATE.TURN_PREPARATION)
			)
			typer.next_text()
	else:
		battle_set_menu(BATTLE_MENU.BUTTON)

func _do_flee():
	# Flee：当前先回到按钮菜单（后续可接入完整逃跑判定）。
	# Transition to overworld placeholder
	battle_set_menu(BATTLE_MENU.BUTTON)

func _on_aim_finished(precision: float, damage_mult: float, miss: bool):
	# FIGHT 瞄准结束回调：计算伤害并切换到 FIGHT_ANIM 计时阶段。
	if has_node("BattleAim"):
		$BattleAim.hide()
	if miss:
		_current_damage = -1
	else:
		var atk = 10 # Placeholder for Player_GetAtkTotal()
		var enemy = battle_get_fight_enemy_choice()
		var def = 0 # Placeholder for Battle_GetEnemyDEF
		
		var base_damage = atk - def + randf_range(0, 2)
		var final_damage = base_damage * damage_mult
		_current_damage = roundi(final_damage)
		if _current_damage <= 0:
			_current_damage = 1
			
	# Move to FIGHT_ANIM
	_fight_anim_time = 50
	_fight_damage_time = 45
	battle_set_menu(BATTLE_MENU.FIGHT_ANIM)

func _end_menu_fight_anim():
	# FIGHT_ANIM 结束：结算伤害、生成跳字/震动，再进入 FIGHT_DAMAGE。
	battle_set_menu(BATTLE_MENU.FIGHT_DAMAGE)
	
	var enemy = battle_get_fight_enemy_choice()
	if enemy:
		if _current_damage > 0:
			enemy.set_hp(enemy.get_hp() - _current_damage)
			
			# Shaker logic for enemy
			var shaker = ShakerClass.new(enemy, "position:x", 10.0, 1, 1.0, false)
			add_child(shaker)
		
		# Spawn damage popup
		var dmg_popup = BattleDamageClass.instantiate()
		dmg_popup.position = enemy.global_position + Vector2(0, -60) # Above enemy center
		add_child(dmg_popup)
		dmg_popup.start(_current_damage, enemy.get_hp_max(), enemy.get_hp())

func _end_menu_fight_damage():
	# FIGHT_DAMAGE 展示结束后，推进到敌方回合准备阶段。
	# Transition to enemy turn after damage finishes
	battle_set_state(BATTLE_STATE.TURN_PREPARATION)

func battle_set_fight_enemy_choice(slot : int):
	# 设置 FIGHT 目标敌人，并同步 selector 与 UI 事件。
	var _slot = _clamp_choice(slot, battle_get_enemy_count())
	battle_fight_enemy_choice = _slot;
	if battle_menu == BATTLE_MENU.FIGHT_ENEMY_CHOICE:
		_menu_selector.set_slot(_slot)
	emit_signal("BattleEvent", EVENT_TYPE.FIGHT_ENEMY_CHOICE_CHANGED, _slot, -1);

func battle_set_act_enemy_choice(slot : int):
	# 设置 ACT 目标敌人，并广播选择变更。
	var _slot = _clamp_choice(slot, battle_get_enemy_count())
	battle_act_enemy_choice = _slot;
	if battle_menu == BATTLE_MENU.ACT_ENEMY_CHOICE:
		_menu_selector.set_slot(_slot)
	emit_signal("BattleEvent", EVENT_TYPE.ACT_ENEMY_CHOICE_CHANGED, _slot, -1);

func battle_set_act_choice(slot : int):
	# 设置 ACT 子菜单中的动作索引。
	var enemy = battle_get_act_enemy_choice()
	var _size = 0
	if enemy != null:
		_size = enemy.action_get_count()
	var _slot = _clamp_choice(slot, _size)
	battle_act_choice = _slot;
	if battle_menu == BATTLE_MENU.ACT_CHOICE:
		_menu_selector.set_slot(_slot)
	emit_signal("BattleEvent", EVENT_TYPE.ACT_CHOICE_CHANGED, _slot, -1);

func battle_set_item_choice(slot : int):
	# 设置 ITEM 子菜单中的物品索引。
	var _slot = _clamp_choice(slot, Global.player_data_items.size())
	battle_item_choice = _slot
	if battle_menu == BATTLE_MENU.ITEM:
		_menu_selector.set_slot(_slot)
	emit_signal("BattleEvent", EVENT_TYPE.ITEM_CHOICE_CHANGED, _slot, -1)

func battle_set_mercy_choice(slot : int):
	# 设置 MERCY 子菜单中的选项索引（Spare/Flee）。
	var _slot = _clamp_choice(slot, 2)
	battle_mercy_choice = _slot
	if battle_menu == BATTLE_MENU.MERCY:
		_menu_selector.set_slot(_slot)
	emit_signal("BattleEvent", EVENT_TYPE.MERCY_CHOICE_CHANGED, _slot, -1)

func battle_get_fight_enemy_choice() -> BattleEnemy:
	# 读取当前 FIGHT 选中的敌人实例。
	return battle_get_enemy(battle_fight_enemy_choice);

func battle_get_act_enemy_choice() -> BattleEnemy:
	# 读取当前 ACT 选中的敌人实例。
	return battle_get_enemy(battle_act_enemy_choice);

func battle_get_act_choice_number() -> int:
	# 读取 ACT 子菜单中当前动作索引。
	return battle_act_choice;

func battle_set_button(slot : int):
	# 设置底部四大按钮高亮位置。
	battle_menu_button = _wrap_button_slot(slot)
	if battle_menu == BATTLE_MENU.BUTTON:
		_menu_selector.set_slot(battle_menu_button)
	emit_signal("BattleEvent", EVENT_TYPE.BUTTON_CHANGED, battle_menu_button, -1);
	
func battle_set_menu(menu : BATTLE_MENU):
	# 菜单切换总入口：切状态、同步 selector、发 UI 事件。
	battle_menu = menu;
	match menu:
		BATTLE_MENU.FIGHT_AIM:
			$BattleAim.start()
			var ui = UImanager.get_ui()
			if ui and ui.menu_renderer:
				ui.menu_renderer.hide_menu()
		BATTLE_MENU.FIGHT_ENEMY_CHOICE:
			battle_set_fight_enemy_choice(battle_fight_enemy_choice);
		BATTLE_MENU.ACT_ENEMY_CHOICE:
			battle_set_act_enemy_choice(battle_act_enemy_choice);
		BATTLE_MENU.ACT_CHOICE:
			battle_set_act_choice(0);
		BATTLE_MENU.ITEM:
			battle_set_item_choice(battle_item_choice)
		BATTLE_MENU.MERCY:
			battle_set_mercy_choice(battle_mercy_choice)
	_sync_selector_with_menu()
	emit_signal("BattleEvent", EVENT_TYPE.MENU_CHANGED, menu, _last_menu);
	_last_menu = menu;

func battle_get_menu():
	# 当前细分菜单状态（按钮/目标选择/物品等）。
	return battle_menu;
	
func battle_get_state():
	# 当前战斗大状态（MENU/DIALOG/TURN 等）。
	return battle_state;

func battle_get_enemy(slot : int) -> BattleEnemy:
	# 通过 EnemyManager 按索引读取敌人。
	return enemy_manager.battle_get_enemy(slot);

func battle_get_enemys():
	# 读取当前敌人列表（按战场顺序）。
	return enemy_manager.battle_get_enemys();

func battle_get_enemy_count():
	# 读取敌人数量，给 selector 和判定使用。
	return enemy_manager.battle_get_enemy_count();

func battle_remove_enemy(slot: int):
	# 从战斗中移除指定敌人（queue_free + remove_at）。
	enemy_manager.battle_remove_enemy(slot)

func battle_has_enemies() -> bool:
	# 是否还有存活敌人。
	return enemy_manager.battle_has_enemies()

func battle_set_enemy(slot : int, packed : PackedScene):
	# 动态替换某个敌人槽位（调试/脚本切敌时用）。
	return enemy_manager.battle_set_enemy(slot, packed);

func battle_set_state(state: BATTLE_STATE):
	# 战斗大状态切换（MENU/DIALOG/TURN 等）。
	_last_state = battle_state
	battle_state = state
	
	match battle_state:
		BATTLE_STATE.MENU:
			pass
		BATTLE_STATE.DIALOG:
			pass
		BATTLE_STATE.TURN_PREPARATION:
			# 敌方回合准备阶段：后续在这里扩展弹幕板缩放与生成。
			pass
		BATTLE_STATE.IN_TURN:
			# 敌方回合执行阶段：后续在这里处理子弹与受击判定。
			pass
		BATTLE_STATE.BOARD_RESETTING:
			# 敌方回合结束后，把战斗框恢复到菜单默认尺寸。
			var default_size = Vector2(573, 140)
			var default_pos = Vector2(320, 320)
			$BattleBox.resize(default_size, default_pos, 0.4)
			# 当前版本自动回到 MENU，便于快速联调四按钮循环。
			await get_tree().create_timer(0.4).timeout
			battle_set_state(BATTLE_STATE.MENU)
			battle_set_menu(BATTLE_MENU.BUTTON)
		BATTLE_STATE.RESULT:
			pass

func _ready() -> void:
	# 初始化：连接瞄准结束信号，同步菜单选择器。
	$BattleAim.aim_finished.connect(_on_aim_finished)
	_sync_selector_with_menu()
	battle_set_button(0);

func _is_action_pressed_no_echo(event: InputEvent, action: String) -> bool:
	# 过滤按键连发（echo），只响应有效的按下事件。
	if not event.is_action_pressed(action):
		return false
	if event is InputEventKey and event.echo:
		return false
	return true

func _is_accept_pressed(event: InputEvent) -> bool:
	# 统一确认键判断：支持 ui_accept，并兜底识别 Z。
	if _is_action_pressed_no_echo(event, "ui_accept"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_Z or event.physical_keycode == KEY_Z
	return false

func _input(event: InputEvent) -> void:
	# 所有菜单输入总入口；根据当前 battle_menu 分发到具体逻辑。
	if battle_state != BATTLE_STATE.MENU:
		return

	match battle_menu:
		BATTLE_MENU.BUTTON:
			if _is_action_pressed_no_echo(event, "ui_right"):
				_menu_move(1)
				return
			if _is_action_pressed_no_echo(event, "ui_left"):
				_menu_move(-1)
				return
			if _is_accept_pressed(event):
				match battle_menu_button:
					0:
						battle_set_menu(BATTLE_MENU.FIGHT_ENEMY_CHOICE)
					1:
						battle_set_menu(BATTLE_MENU.ACT_ENEMY_CHOICE)
					2:
						if not Global.player_data_items.is_empty():
							battle_set_menu(BATTLE_MENU.ITEM)
					3:
						battle_set_menu(BATTLE_MENU.MERCY)
				return
		BATTLE_MENU.FIGHT_ENEMY_CHOICE:
			if _is_action_pressed_no_echo(event, "ui_right") or _is_action_pressed_no_echo(event, "ui_down"):
				_menu_move(1)
				return
			if _is_action_pressed_no_echo(event, "ui_left") or _is_action_pressed_no_echo(event, "ui_up"):
				_menu_move(-1)
				return
			if _is_accept_pressed(event):
				battle_set_menu(BATTLE_MENU.FIGHT_AIM)
				return
			if _is_action_pressed_no_echo(event, "ui_cancel"):
				battle_set_menu(BATTLE_MENU.BUTTON)
				return
		BATTLE_MENU.FIGHT_AIM:
			if _is_accept_pressed(event):
				$BattleAim.stop_aim()
				return
		BATTLE_MENU.ACT_ENEMY_CHOICE:
			if _is_action_pressed_no_echo(event, "ui_right"):
				_menu_move(1)
				return
			if _is_action_pressed_no_echo(event, "ui_left"):
				_menu_move(-1)
				return
			if _is_accept_pressed(event):
				var enemy = battle_get_act_enemy_choice()
				if enemy != null and enemy.action_get_count() > 0:
					battle_set_menu(BATTLE_MENU.ACT_CHOICE)
				return
			if _is_action_pressed_no_echo(event, "ui_cancel"):
				battle_set_menu(BATTLE_MENU.BUTTON)
				return
		BATTLE_MENU.ACT_CHOICE:
			if _is_action_pressed_no_echo(event, "ui_right"):
				_menu_move(1)
				return
			if _is_action_pressed_no_echo(event, "ui_left"):
				_menu_move(-1)
				return
			if _is_accept_pressed(event):
				_do_act()
				return
			if _is_action_pressed_no_echo(event, "ui_cancel"):
				battle_set_menu(BATTLE_MENU.ACT_ENEMY_CHOICE)
				return
		BATTLE_MENU.ITEM:
			if _is_action_pressed_no_echo(event, "ui_right") or _is_action_pressed_no_echo(event, "ui_down"):
				_menu_move(1)
				return
			if _is_action_pressed_no_echo(event, "ui_left") or _is_action_pressed_no_echo(event, "ui_up"):
				_menu_move(-1)
				return
			if _is_accept_pressed(event):
				_use_selected_item()
				return
			if _is_action_pressed_no_echo(event, "ui_cancel"):
				battle_set_menu(BATTLE_MENU.BUTTON)
				return
		BATTLE_MENU.MERCY:
			if _is_action_pressed_no_echo(event, "ui_right") or _is_action_pressed_no_echo(event, "ui_down"):
				_menu_move(1)
				return
			if _is_action_pressed_no_echo(event, "ui_left") or _is_action_pressed_no_echo(event, "ui_up"):
				_menu_move(-1)
				return
			if _is_accept_pressed(event):
				_confirm_mercy_choice()
				return
			if _is_action_pressed_no_echo(event, "ui_cancel"):
				battle_set_menu(BATTLE_MENU.BUTTON)
				return

func _process(_delta: float) -> void:
	# 每帧处理：更新 soul 光标位置，并处理 FIGHT_ANIM/FIGHT_DAMAGE 倒计时。
	if(battle_state == BATTLE_STATE.MENU):
		var UI = UImanager.get_ui();
		
		match battle_menu:
			BATTLE_MENU.FIGHT_ENEMY_CHOICE, BATTLE_MENU.ACT_ENEMY_CHOICE, \
			BATTLE_MENU.ACT_CHOICE, BATTLE_MENU.ITEM, BATTLE_MENU.MERCY:
				var pos = UI.menu_renderer.get_option_position(_menu_selector.get_slot())
				soul.position = lerp(soul.position, pos + Vector2(-20, 15), 1 - 0.001 ** _delta)
			BATTLE_MENU.BUTTON:
				var slot = UI.get_button_slot();
				match slot:
					0:
						soul.position = UI.get_button(slot).global_position + Vector2(-38, 0);
					1:
						soul.position = UI.get_button(slot).global_position + Vector2(-38, 0);
					2:
						soul.position = UI.get_button(slot).global_position + Vector2(-38, 0);
					3:
						soul.position = UI.get_button(slot).global_position + Vector2(-39, 0);
		
		match battle_menu:
			BATTLE_MENU.FIGHT_ANIM:
				if _fight_anim_time > 0:
					_fight_anim_time -= 1
				elif _fight_anim_time == 0:
					_end_menu_fight_anim()
					_fight_anim_time -= 1
			BATTLE_MENU.FIGHT_DAMAGE:
				if _fight_damage_time > 0:
					_fight_damage_time -= 1
				elif _fight_damage_time == 0:
					_end_menu_fight_damage()
					_fight_damage_time -= 1
