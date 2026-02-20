class_name Battle extends Node

@onready var box_typer = $BoxTyper;

@export var items : BattleItemManager;
@export var enemy_actions : BattleEnemyActions;
@export var enemy_selections : BattleEnemySelections;
@export var UImanager : BattleUIManager;
@export var enemy_manager : EnemyManager;
@export var soul : BattleSoulRed;

enum EVENT_TYPE{
	MENU_CHANGED,
	BUTTON_CHANGED,
	FIGHT_ENEMY_CHOICE_CHANGED,
	ACT_ENEMY_CHOICE_CHANGED,
	ACT_CHOICE_CHANGED,
	ITEM_CHOICE_CHANGED
}

enum BATTLE_MENU{
	BUTTON,
	FIGHT_ENEMY_CHOICE,
	FIGHT_AIM,
	FIGHT_ANIM,
	ACT_ENEMY_CHOICE,
	ACT_CHOICE,
	ITEM,
	ITEM_INFO
}
enum BATTLE_STATE{
	MENU,
}

signal BattleEvent(TYPE: EVENT_TYPE, EVENT: Variant, FORM: Variant);

var battle_menu : BATTLE_MENU = BATTLE_MENU.BUTTON;
var _last_menu : BATTLE_MENU = BATTLE_MENU.BUTTON;
var battle_state : BATTLE_STATE = BATTLE_STATE.MENU;
var _last_state : BATTLE_STATE = BATTLE_STATE.MENU;
var battle_fight_enemy_choice : int = 0;
var battle_act_enemy_choice : int = 0;
var battle_act_choice : int = 0;
var battle_item_choice : int = 0;
var battle_item_page : int = 0;

var battle_menu_button : int = 0;

func battle_set_fight_enemy_choice(slot : int):
	var _slot = slot;
	if(_slot < 0):
		_slot = 0;
	elif(_slot >= battle_get_enemy_count()):
		_slot = battle_get_enemy_count()-1;
	battle_fight_enemy_choice = _slot;
	enemy_selections.hide_info(false);
	enemy_selections.set_slot(_slot);
	soul.position = enemy_selections.selections[_slot].position;
	emit_signal("BattleEvent", EVENT_TYPE.FIGHT_ENEMY_CHOICE_CHANGED, _slot, -1);

func battle_set_act_enemy_choice(slot : int):
	var _slot = slot;
	if(_slot < 0):
		_slot = 0;
	elif(_slot >= battle_get_enemy_count()):
		_slot = battle_get_enemy_count()-1;
	battle_act_enemy_choice = _slot;
	enemy_selections.hide_info(true);
	enemy_selections.set_slot(_slot);
	soul.position = enemy_selections.selections[_slot].position;
	emit_signal("BattleEvent", EVENT_TYPE.ACT_ENEMY_CHOICE_CHANGED, _slot, -1);

func battle_set_act_choice(slot : int):
	var _size = battle_get_act_enemy_choice().action_get_count();
	var _slot = slot;
	if(_slot < 0):
		_slot = 0;
	elif(_slot >= _size):
		_slot = _size-1;
	battle_act_choice = _slot;
	enemy_actions.set_actions_name(battle_get_act_enemy_choice().get_actions());
	soul.position = enemy_actions.selections[battle_get_act_choice_number()].position-Vector2(36,0);
	emit_signal("BattleEvent", EVENT_TYPE.ACT_CHOICE_CHANGED, _slot, -1);

func battle_set_item_choice(slot : int):
	var _size = Global.player_get_item_count();
	var _slot = slot;
	if(_slot < 0):
		_slot = 0;
	elif(_slot >= _size):
		_slot = _size-1;
	battle_item_choice = _slot;
	while(_slot < battle_item_page):
		battle_item_page -= 1;
	while(_slot > battle_item_page+2):
		battle_item_page += 1;
	items.set_slot(_slot);
	soul.position = Vector2(85,288 + 32*(_slot - battle_item_page));
	emit_signal("BattleEvent", EVENT_TYPE.ITEM_CHOICE_CHANGED, _slot, -1);

func battle_get_fight_enemy_choice() -> BattleEnemy:
	return battle_get_enemy(battle_fight_enemy_choice);

func battle_get_act_enemy_choice() -> BattleEnemy:
	return battle_get_enemy(battle_act_enemy_choice);

func battle_get_act_choice_number() -> int:
	return battle_act_choice;

func battle_set_button(slot : int):
	battle_menu_button = slot;
	emit_signal("BattleEvent", EVENT_TYPE.BUTTON_CHANGED, slot, -1);
	battle_menu_button = UImanager.get_ui().get_button_slot();
	
	
func battle_set_menu(menu : BATTLE_MENU):
	battle_menu = menu;
	match menu:
		BATTLE_MENU.BUTTON:
			box_typer.visible = true;
			for i in range(3):
				enemy_selections.hide_enemy(i, true);
			items.hide_all(true);
				
		BATTLE_MENU.FIGHT_ENEMY_CHOICE:
			box_typer.skip();
			box_typer.visible = false;
			for i in range(3):
				var enemys = enemy_manager.battle_get_enemys();
				if(len(enemys)>i):
					var enemy = enemy_manager.battle_get_enemy(i);
					enemy_selections.hide_enemy(i, false);
					enemy_selections.set_enemy_info(i, enemy.get_enemy_name(), \
						enemy.get_hp(), enemy.get_hp_max());
				else:
					enemy_selections.hide_enemy(i, true);
			battle_set_fight_enemy_choice(battle_fight_enemy_choice);
		BATTLE_MENU.ACT_ENEMY_CHOICE:
			enemy_actions.hide_all_actions(true);
			box_typer.skip();
			box_typer.visible = false;
			for i in range(3):
				var enemys = enemy_manager.battle_get_enemys();
				if(len(enemys)>i):
					var enemy = enemy_manager.battle_get_enemy(i);
					enemy_selections.hide_enemy(i, false);
					enemy_selections.set_enemy_info(i, enemy.get_enemy_name(), \
						enemy.get_hp(), enemy.get_hp_max());
				else:
					enemy_selections.hide_enemy(i, true);
			battle_set_act_enemy_choice(battle_act_enemy_choice);
		BATTLE_MENU.ACT_CHOICE:
			for i in range(3):
				enemy_selections.hide_enemy(i, true);
			battle_set_act_choice(0);
		BATTLE_MENU.ITEM:
			box_typer.skip();
			box_typer.visible = false;
			items.set_items(Global.player_get_items());
			battle_set_item_choice(battle_item_choice);
		BATTLE_MENU.ITEM_INFO:
			var item_id = Global.player_get_items()[battle_item_choice];
			var item = ItemManager.item_get(item_id);
			items.hide_all(true);
			box_typer.clear_text();
			box_typer.visible = true;
			box_typer.text_add(item.info(), func(t): t.pause_text());
			box_typer.skip();
	emit_signal("BattleEvent", EVENT_TYPE.MENU_CHANGED, menu, _last_menu);
	_last_menu = menu;

func battle_get_menu():
	return battle_menu;
	
func battle_get_state():
	return battle_state;

func battle_get_enemy(slot : int) -> BattleEnemy:
	return enemy_manager.battle_get_enemy(slot);

func battle_get_enemys():
	return enemy_manager.battle_get_enemys();

func battle_get_enemy_count():
	return enemy_manager.battle_get_enemy_count();

func battle_set_enemy(slot : int, packed : PackedScene):
	return enemy_manager.battle_set_enemy(slot, packed);

func _ready() -> void:
	
	battle_set_button(0);

# 通用线性切换器（上下导航），count 为选项数量，current 为当前索引，setter 为更新回调
func generic_switcher_1d(count: int, current: int, setter: Callable) -> void:
	var new_val = current;
	if Input.is_action_just_pressed("ui_down"):
		new_val += 1;
	elif Input.is_action_just_pressed("ui_up"):
		new_val -= 1;
	new_val = clampi(new_val, 0, count - 1);
	if new_val != current:
		setter.call(new_val);

# 通用网格切换器（上下左右导航），cols 为列数
func generic_switcher_2d(count: int, current: int, cols: int, setter: Callable) -> void:
	var new_val = current;
	if Input.is_action_just_pressed("ui_right") and (current % cols) < cols - 1 and current + 1 < count:
		new_val = current + 1;
	elif Input.is_action_just_pressed("ui_left") and (current % cols) > 0:
		new_val = current - 1;
	elif Input.is_action_just_pressed("ui_down") and current + cols < count:
		new_val = current + cols;
	elif Input.is_action_just_pressed("ui_up") and current - cols >= 0:
		new_val = current - cols;
	if new_val != current:
		setter.call(new_val);
func batlle_menu_button():
	var UI = UImanager.get_ui();
	if Input.is_action_just_pressed("ui_right"):
		battle_menu_button = (battle_menu_button + 1) % 4;
		battle_set_button(battle_menu_button);
	elif Input.is_action_just_pressed("ui_left"):
		battle_menu_button = (battle_menu_button - 1 + 4) % 4;
		battle_set_button(battle_menu_button);
	
	soul.position = UI.get_button(battle_menu_button).global_position + Vector2(-38, 0);
	if Input.is_action_just_pressed("ui_accept"):
		var next_menus = [
			BATTLE_MENU.FIGHT_ENEMY_CHOICE,
			BATTLE_MENU.ACT_ENEMY_CHOICE,
			BATTLE_MENU.ITEM,
		];
		if battle_menu_button < next_menus.size():
			if battle_menu_button != 2 or Global.player_get_item_count() > 0:
				battle_set_menu(next_menus[battle_menu_button]);

func _process(_delta: float) -> void:
	if(battle_state == BATTLE_STATE.MENU):
		if(battle_menu == BATTLE_MENU.BUTTON):
			batlle_menu_button();
			
		#FIGHT分支
		elif battle_menu == BATTLE_MENU.FIGHT_ENEMY_CHOICE:
			generic_switcher_1d(battle_get_enemy_count(), battle_fight_enemy_choice, battle_set_fight_enemy_choice);
			if Input.is_action_just_pressed("ui_accept"):
				battle_set_menu(BATTLE_MENU.FIGHT_AIM);
			elif Input.is_action_just_pressed("ui_cancel"):
				battle_set_menu(BATTLE_MENU.BUTTON);
		elif battle_menu == BATTLE_MENU.FIGHT_AIM:
			pass;
		elif battle_menu == BATTLE_MENU.ACT_ENEMY_CHOICE:
			generic_switcher_1d(battle_get_enemy_count(), battle_act_enemy_choice, battle_set_act_enemy_choice);
			if Input.is_action_just_pressed("ui_accept"):
				battle_set_menu(BATTLE_MENU.ACT_CHOICE);
			elif Input.is_action_just_pressed("ui_cancel"):
				battle_set_menu(BATTLE_MENU.BUTTON);
		elif battle_menu == BATTLE_MENU.ACT_CHOICE:
			generic_switcher_2d(battle_get_act_enemy_choice().action_get_count(), battle_act_choice, 2, battle_set_act_choice);
			if Input.is_action_just_pressed("ui_accept"):
				battle_set_menu(BATTLE_MENU.ACT_CHOICE);
			elif Input.is_action_just_pressed("ui_cancel"):
				battle_set_menu(BATTLE_MENU.ACT_ENEMY_CHOICE);
		elif battle_menu == BATTLE_MENU.ITEM:
			generic_switcher_1d(Global.player_get_item_count(), battle_item_choice, battle_set_item_choice);
			if Input.is_action_just_pressed("ui_accept"):
				battle_set_menu(BATTLE_MENU.ITEM_INFO);
			elif Input.is_action_just_pressed("ui_cancel"):
				battle_set_menu(BATTLE_MENU.BUTTON);
		elif battle_menu == BATTLE_MENU.ITEM_INFO:
			if Input.is_action_just_pressed("ui_accept"):
				var item_id = Global.player_get_items()[battle_item_choice];
				ItemManager.item_get(item_id).use();
				battle_set_menu(BATTLE_MENU.BUTTON);
			elif Input.is_action_just_pressed("ui_cancel"):
				battle_set_menu(BATTLE_MENU.ITEM);
