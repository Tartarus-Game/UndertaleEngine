class_name Battle extends Node

@export var UImanager : BattleUIManager;
@export var enemy_manager : EnemyManager;
@export var soul : BattleSoulRed;

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
	MERCY_CHOICE_CHANGED,
	# 决策执行类事件：在玩家最终确认操作时广播。
	FIGHT_CONFIRMED,   # 确认 FIGHT 目标，即将进入瞄准；EVENT = 目标敌人槽位
	ACT_CONFIRMED,     # ACT 选项被执行；EVENT = 敌人槽位，FORM = 动作索引
	ITEM_USED,         # 物品已使用并从背包移除；EVENT = 物品对象，FORM = 使用前槽位
	MERCY_CONFIRMED,   # MERCY 选项被确认执行；EVENT = 选项索引（0=Spare, 1=Flee）
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
	# 战斗大状态：菜单、敌方回合、结算。
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
# 是否正在播放对话文本（在 MENU 状态内屏蔽方向键，但允许 Z 推进打字机）。
var _is_dialog: bool = false
var dialog_queue : Array = [];
# BUTTON 状态下打字机显示的空闲文本（encounter/turn dialog 的最后一行）。
var _button_idle_text: String = ""
var _button_typer_effect_enable : bool = false;
var battle_fight_enemy_choice : int = 0;
var battle_act_enemy_choice : int = 0;
var battle_act_choice : int = 0;
var battle_item_choice : int = 0;
var battle_mercy_choice : int = 0;

var battle_menu_button : int = 0;
# 通用选择器：1D 用于线性列表，2D 用于多列网格（物品、ACT 动作）。
var _selector_1d: MenuSelector1D = MenuSelector1D.new()
var _selector_2d: MenuSelector2D = MenuSelector2D.new()

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

func _is_menu_2d(menu: BATTLE_MENU) -> bool:
	# 判断菜单是否为二维网格布局（2 列，与 BattleMenuRenderer.COLUMNS 对应）。
	return menu == BATTLE_MENU.ITEM or menu == BATTLE_MENU.ACT_CHOICE or menu == BATTLE_MENU.MERCY

func _get_selector():
	# 根据当前菜单返回对应的选择器实例。
	if _is_menu_2d(battle_menu):
		return _selector_2d
	return _selector_1d

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
			return ["Spare","Flee"]
	return []

func _sync_selector_with_menu(keep_slot: bool = false):
	# 让 selector 的 options/slot 与当前 battle_menu 状态保持一致。
	var opts = _build_menu_selector_options(battle_menu)
	if _is_menu_2d(battle_menu):
		_selector_2d.set_options(opts, 2, keep_slot)
	else:
		_selector_1d.wrap = (battle_menu == BATTLE_MENU.BUTTON)
		_selector_1d.set_options(opts, keep_slot)
	match battle_menu:
		BATTLE_MENU.BUTTON:
			_selector_1d.set_slot(battle_menu_button)
		BATTLE_MENU.FIGHT_ENEMY_CHOICE:
			_selector_1d.set_slot(battle_fight_enemy_choice)
		BATTLE_MENU.ACT_ENEMY_CHOICE:
			_selector_1d.set_slot(battle_act_enemy_choice)
		BATTLE_MENU.ACT_CHOICE:
			_selector_2d.set_slot(battle_act_choice)
		BATTLE_MENU.ITEM:
			_selector_2d.set_slot(battle_item_choice)
		BATTLE_MENU.MERCY:
			_selector_2d.set_slot(battle_mercy_choice)

func _apply_selector_to_menu():
	# 把 selector 当前选中项回写到具体业务字段（按钮、敌人、物品等）。
	var selected_slot = _get_selector().get_slot()
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
	# 水平方向移动：1D 直接 move，2D 调用 move_x。
	var sel = _get_selector()
	if sel.get_size() <= 0:
		return
	if sel is MenuSelector2D:
		sel.move_x(offset)
	else:
		sel.move(offset)
	_apply_selector_to_menu()

func _menu_move_vertical(offset: int):
	# 垂直方向移动：仅对 2D selector 有效。
	var sel = _get_selector()
	if not sel is MenuSelector2D or sel.get_size() <= 0:
		return
	sel.move_y(offset)
	_apply_selector_to_menu()

func _do_act():
	soul.hide()
	
	var ui = UImanager.get_ui()
	if ui and ui.menu_renderer:
		ui.menu_renderer.hide_menu()
	if ui and ui.vertical_menu_renderer:
		ui.vertical_menu_renderer.hide_menu()
		
	battle_set_state(BATTLE_STATE.DIALOG)

func _use_selected_item():
	
	# 执行 ITEM：使用物品、从背包移除，并显示使用文本。
	if Global.player_data_items.is_empty():
		return
	
	battle_item_choice = _clamp_choice(battle_item_choice, Global.player_data_items.size())
	soul.hide()
	var selected_item = Global.player_data_items[battle_item_choice]
	var item_name = "item"
	if typeof(selected_item) == TYPE_OBJECT and selected_item.has_method("name"):
		var maybe_name = selected_item.name()
		if maybe_name != null:
			item_name = str(maybe_name)
	else:
		item_name = str(selected_item)
	
	if typeof(selected_item) == TYPE_OBJECT and selected_item.has_method("use"):
		selected_item.use(battle_item_choice, Global.player_data_items)
	var _used_slot = battle_item_choice
	
	emit_signal("BattleEvent", EVENT_TYPE.ITEM_USED, selected_item, _used_slot)
	
	var ui = UImanager.get_ui()
	if ui and ui.menu_renderer:
		ui.menu_renderer.hide_menu()

	battle_set_state(BATTLE_STATE.DIALOG)
	
func _confirm_mercy_choice():
	# 执行 MERCY 确认入口，根据当前选择分发到 Spare/Flee。
	emit_signal("BattleEvent", EVENT_TYPE.MERCY_CONFIRMED, battle_mercy_choice, -1)
	match battle_mercy_choice:
		0:
			_do_spare()
		1:
			_do_flee()

func _do_spare():
	# Spare：移除所有可饶恕敌人；若清场则进入 RESULT，否则继续战斗流程。
	soul.hide()
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
			_is_dialog = true
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
				_is_dialog = false
				battle_set_state(BATTLE_STATE.RESULT)
			)
			typer.next_text()
			battle_set_state(BATTLE_STATE.DIALOG)
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
##攻击-敌人-选项的切换
func battle_set_fight_enemy_choice(slot : int):
	# 设置 FIGHT 目标敌人，并同步 selector 与 UI 事件。
	var _slot = _clamp_choice(slot, battle_get_enemy_count())
	battle_fight_enemy_choice = _slot;
	if battle_menu == BATTLE_MENU.FIGHT_ENEMY_CHOICE:
		_selector_1d.set_slot(_slot)
	emit_signal("BattleEvent", EVENT_TYPE.FIGHT_ENEMY_CHOICE_CHANGED, _slot, -1);
##动作-敌人-敌人选项的切换
func battle_set_act_enemy_choice(slot : int):
	# 设置 ACT 目标敌人，并广播选择变更。
	var _slot = _clamp_choice(slot, battle_get_enemy_count())
	battle_act_enemy_choice = _slot;
	if battle_menu == BATTLE_MENU.ACT_ENEMY_CHOICE:
		_selector_1d.set_slot(_slot)
	emit_signal("BattleEvent", EVENT_TYPE.ACT_ENEMY_CHOICE_CHANGED, _slot, -1);
##动作-敌人-动作选项的切换
func battle_set_act_choice(slot : int):
	# 设置 ACT 子菜单中的动作索引。
	var enemy = battle_get_act_enemy_choice()
	var _size = 0
	if enemy != null:
		_size = enemy.action_get_count()
	var _slot = _clamp_choice(slot, _size)
	battle_act_choice = _slot;
	if battle_menu == BATTLE_MENU.ACT_CHOICE:
		_selector_2d.set_slot(_slot)
	emit_signal("BattleEvent", EVENT_TYPE.ACT_CHOICE_CHANGED, _slot, -1);
##物品-物品选项的切换
func battle_set_item_choice(slot : int):
	# 设置 ITEM 子菜单中的物品索引。
	var _slot = _clamp_choice(slot, Global.player_data_items.size())
	battle_item_choice = _slot
	if battle_menu == BATTLE_MENU.ITEM:
		_selector_2d.set_slot(_slot)
	emit_signal("BattleEvent", EVENT_TYPE.ITEM_CHOICE_CHANGED, _slot, -1)
##仁慈-仁慈选项的切换
func battle_set_mercy_choice(slot : int):
	# 设置 MERCY 子菜单中的选项索引（Spare/Flee）。
	var _slot = _clamp_choice(slot, 2)
	battle_mercy_choice = _slot
	if battle_menu == BATTLE_MENU.MERCY:
		_selector_1d.set_slot(_slot)
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
#按钮切换
func battle_set_button(slot : int):
	# 设置底部四大按钮高亮位置。
	battle_menu_button = _wrap_button_slot(slot)
	if battle_menu == BATTLE_MENU.BUTTON:
		_selector_1d.set_slot(battle_menu_button)
	emit_signal("BattleEvent", EVENT_TYPE.BUTTON_CHANGED, battle_menu_button, -1);
	
func battle_set_menu(menu : BATTLE_MENU):
	# 菜单切换总入口：切状态、同步 selector、发 UI 事件。
	var leaving_button = (_last_menu == BATTLE_MENU.BUTTON and menu != BATTLE_MENU.BUTTON)
	var entering_button = (menu == BATTLE_MENU.BUTTON and _last_menu != BATTLE_MENU.BUTTON)
	battle_menu = menu;
	
	# 离开 BUTTON 时清空打字机（移除残留的 encounter/turn 文本）。
	if leaving_button:
		_button_typer_effect_enable = false
		_clear_typer()
	
	match menu:
		BATTLE_MENU.BUTTON:
			# 回到 BUTTON 时恢复空闲文本。
			if entering_button and _button_idle_text != "" and !_button_typer_effect_enable:
				_show_button_idle_text()
			if(_button_typer_effect_enable):
				_show_button_idle_text_with_type_effect()
		BATTLE_MENU.FIGHT_AIM:
			$BattleAim.start()
			var ui = UImanager.get_ui()
			if ui:
				soul.hide()
				if ui.menu_renderer:
					ui.menu_renderer.hide_menu()
				if ui.vertical_menu_renderer:
					ui.vertical_menu_renderer.hide_menu()
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

func battle_get_enemys() -> Array[BattleEnemy]:
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
			_button_typer_effect_enable = true
			soul.set_move_able(false)
		BATTLE_STATE.DIALOG:
			var typer = $TextTyper
			while(DialogueManager.get_dialogue_size() > 0):
				var dialoge = DialogueManager.enqueue_dialogue()
				typer.text_add(dialoge.text, dialoge.callable);
			typer.text_add("", 
			func(t): 
				t.pause = false
				t.clear_text()
				battle_set_state(BATTLE_STATE.TURN_PREPARATION)
			)
			typer.next_text()
		BATTLE_STATE.TURN_PREPARATION:
			# 收集所有敌人本回合台词，用打字机展示，玩家确认后切入 BOARD_RESETTING。
			var lines: Array = []
			for enemy in battle_get_enemys():
				var line = enemy.get_turn_dialog()
				if line != "":
					lines.append(line)
			
			var ui = UImanager.get_ui()
			if ui:
				if ui.menu_renderer:
					ui.menu_renderer.hide_menu()
				if ui.vertical_menu_renderer:
					ui.vertical_menu_renderer.hide_menu()
			soul.show()
			
			_clear_typer()
			
			if lines.is_empty():
				# 敌人无台词，直接进入回合
				battle_set_state(BATTLE_STATE.BOARD_RESETTING)
			else:
				var typer = $TextTyper
				for i in range(lines.size()):
					var line = lines[i]
					if i < lines.size() - 1:
						typer.text_add(line, func(t): t.pause = true)
					else:
						# 最后一条台词确认后切入回合
						typer.text_add(line, func(t): t.pause = true)
						typer.text_add("", func(t):
							_button_idle_text = t.text
							t.clear_text()
							t.pause = false
							battle_set_state(BATTLE_STATE.BOARD_RESETTING)
						)
				typer.next_text()
		BATTLE_STATE.IN_TURN:
			# 敌方回合执行阶段：后续在这里处理子弹与受击判定。
			soul.set_move_able(true)
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

func _clear_typer():
	# 清空打字机文本和队列。
	var typer = $TextTyper
	typer.clear_text()
	typer.texts.clear()
	typer.pause = false

func _show_button_idle_text():
	# 在 BUTTON 状态下立即显示空闲文本（无打字效果）。
	var typer = $TextTyper
	typer.texts.clear()
	typer.text = _button_idle_text
	typer.visible_characters = typer.get_total_character_count()
	typer.pause = true

func _show_button_idle_text_with_type_effect():
	# 在 BUTTON 状态下立即显示空闲文本（有打字效果）。
	var typer = $TextTyper
	typer.texts.clear()
	typer.text = _button_idle_text
	typer.visible_characters = 0
	typer.pause = true

func _show_encounter_dialog():
	# 收集所有敌人遇到文本，通过打字机依次播放，结束后进入 BUTTON 菜单。
	var encounter_lines: Array = []
	for enemy in battle_get_enemys():
		var line = enemy.get_encounter_dialog()
		if line != "":
			encounter_lines.append(line)
	
	_clear_typer()
	
	if encounter_lines.is_empty():
		_button_idle_text = ""
		battle_set_menu(BATTLE_MENU.BUTTON)
	else:
		_is_dialog = true
		var typer = $TextTyper
		for i in range(encounter_lines.size()):
			var line = encounter_lines[i]
			typer.text_add(line, func(t): t.pause = true)
		typer.text_add("", func(t):
			_button_idle_text = t.text
			t.pause = false
			_is_dialog = false
			battle_set_menu(BATTLE_MENU.BUTTON)
		)
		typer.next_text()

func _ready() -> void:
	# 初始化：连接瞄准结束信号，同步菜单选择器，然后显示遇到介绍文本。
	if(!SceneManager.is_battle()):return
	var _enemys = EncounterManager.get_current_encounter_enemys()
	enemy_manager.battle_load_enemy(_enemys)
	$BattleAim.aim_finished.connect(_on_aim_finished)
	_sync_selector_with_menu()
	battle_set_button(0)
	_button_idle_text = EncounterManager.get_current_encounter_text()
	var typer = $TextTyper
	typer.text = _button_idle_text
	typer.next_text();


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
# 打字机推进：对话标志或 TURN_PREPARATION 状态下，Z 键继续文字。
	# 若 Z 恰好把 _is_dialog 清为 false，则不 return，让同一次按键也能触发菜单操作。
	if battle_state == BATTLE_STATE.DIALOG:
		if _is_accept_pressed(event):
			var typer = $TextTyper
			if typer.pause:
				typer.pause = false
				typer.next_text()
		
	
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
			if  _is_action_pressed_no_echo(event, "ui_down"):
				_menu_move(1)
				return
			if _is_action_pressed_no_echo(event, "ui_up"):
				_menu_move(-1)
				return
			if _is_accept_pressed(event):
				emit_signal("BattleEvent", EVENT_TYPE.FIGHT_CONFIRMED, battle_fight_enemy_choice, -1)
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
			if _is_action_pressed_no_echo(event, "ui_down"):
				_menu_move(1)
				return
			if _is_action_pressed_no_echo(event, "ui_up"):
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
			if _is_action_pressed_no_echo(event, "ui_down"):
				_menu_move_vertical(1)
				return
			if _is_action_pressed_no_echo(event, "ui_up"):
				_menu_move_vertical(-1)
				return
			if _is_accept_pressed(event):
				emit_signal("BattleEvent", EVENT_TYPE.ACT_CONFIRMED, battle_act_enemy_choice, -1)

				_do_act()
				return
			if _is_action_pressed_no_echo(event, "ui_cancel"):
				battle_set_menu(BATTLE_MENU.ACT_ENEMY_CHOICE)
				return
		BATTLE_MENU.ITEM:
			if _is_action_pressed_no_echo(event, "ui_right"):
				_menu_move(1)
				return
			if _is_action_pressed_no_echo(event, "ui_left"):
				_menu_move(-1)
				return
			if _is_action_pressed_no_echo(event, "ui_down"):
				_menu_move_vertical(1)
				return
			if _is_action_pressed_no_echo(event, "ui_up"):
				_menu_move_vertical(-1)
				return
			if _is_accept_pressed(event):
				_use_selected_item()
				return
			if _is_action_pressed_no_echo(event, "ui_cancel"):
				battle_set_menu(BATTLE_MENU.BUTTON)
				return
		BATTLE_MENU.MERCY:
			if _is_action_pressed_no_echo(event, "ui_down"):
				_menu_move(1)
				return
			if _is_action_pressed_no_echo(event, "ui_up"):
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
			BATTLE_MENU.FIGHT_ENEMY_CHOICE, BATTLE_MENU.ACT_ENEMY_CHOICE, BATTLE_MENU.MERCY:
				var pos = UI.vertical_menu_renderer.get_option_position(_get_selector().get_slot())
				soul.position = pos
			BATTLE_MENU.ACT_CHOICE, BATTLE_MENU.ITEM:
				var pos = UI.menu_renderer.get_option_position(_get_selector().get_slot())
				soul.position = pos
			BATTLE_MENU.BUTTON:
				var slot = UI.get_button_slot();
				soul.position = UI.get_button_position(slot)
		
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
