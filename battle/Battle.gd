class_name Battle extends Node

@export var UImanager : BattleUIManager;
@export var enemy_manager : EnemyManager;
@export var soul : BattleSoulRed;

const BattleMenuSelectorClass = preload("res://battle/UI/BattleMenuSelector.gd")

enum EVENT_TYPE{
	MENU_CHANGED,
	BUTTON_CHANGED,
	FIGHT_ENEMY_CHOICE_CHANGED,
	ACT_ENEMY_CHOICE_CHANGED,
	ACT_CHOICE_CHANGED,
	ITEM_CHOICE_CHANGED,
	MERCY_CHOICE_CHANGED
}

enum BATTLE_MENU{
	BUTTON,
	FIGHT_ENEMY_CHOICE,
	FIGHT_AIM,
	FIGHT_ANIM,
	ACT_ENEMY_CHOICE,
	ACT_CHOICE,
	ITEM,
	MERCY
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
var battle_mercy_choice : int = 0;

var battle_menu_button : int = 0;
var _menu_selector = BattleMenuSelectorClass.new()

func _clamp_choice(slot: int, size: int) -> int:
	if size <= 0:
		return 0
	return clampi(slot, 0, size - 1)

func _wrap_button_slot(slot: int) -> int:
	if slot < 0:
		return 3
	if slot > 3:
		return 0
	return slot

func _build_menu_selector_options(menu: BATTLE_MENU) -> Array:
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
	if _menu_selector.get_size() <= 0:
		return
	_menu_selector.move(offset)
	_apply_selector_to_menu()

func _use_selected_item():
	if Global.player_data_items.is_empty():
		return
	battle_item_choice = _clamp_choice(battle_item_choice, Global.player_data_items.size())
	var selected_item = Global.player_data_items[battle_item_choice]
	if selected_item is Item:
		selected_item.use()
	Global.player_data_items.remove_at(battle_item_choice)
	battle_set_menu(BATTLE_MENU.BUTTON)

func _confirm_mercy_choice():
	battle_set_menu(BATTLE_MENU.BUTTON)

func battle_set_fight_enemy_choice(slot : int):
	var _slot = _clamp_choice(slot, battle_get_enemy_count())
	battle_fight_enemy_choice = _slot;
	if battle_menu == BATTLE_MENU.FIGHT_ENEMY_CHOICE:
		_menu_selector.set_slot(_slot)
	emit_signal("BattleEvent", EVENT_TYPE.FIGHT_ENEMY_CHOICE_CHANGED, _slot, -1);

func battle_set_act_enemy_choice(slot : int):
	var _slot = _clamp_choice(slot, battle_get_enemy_count())
	battle_act_enemy_choice = _slot;
	if battle_menu == BATTLE_MENU.ACT_ENEMY_CHOICE:
		_menu_selector.set_slot(_slot)
	emit_signal("BattleEvent", EVENT_TYPE.ACT_ENEMY_CHOICE_CHANGED, _slot, -1);

func battle_set_act_choice(slot : int):
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
	var _slot = _clamp_choice(slot, Global.player_data_items.size())
	battle_item_choice = _slot
	if battle_menu == BATTLE_MENU.ITEM:
		_menu_selector.set_slot(_slot)
	emit_signal("BattleEvent", EVENT_TYPE.ITEM_CHOICE_CHANGED, _slot, -1)

func battle_set_mercy_choice(slot : int):
	var _slot = _clamp_choice(slot, 2)
	battle_mercy_choice = _slot
	if battle_menu == BATTLE_MENU.MERCY:
		_menu_selector.set_slot(_slot)
	emit_signal("BattleEvent", EVENT_TYPE.MERCY_CHOICE_CHANGED, _slot, -1)

func battle_get_fight_enemy_choice() -> BattleEnemy:
	return battle_get_enemy(battle_fight_enemy_choice);

func battle_get_act_enemy_choice() -> BattleEnemy:
	return battle_get_enemy(battle_act_enemy_choice);

func battle_get_act_choice_number() -> int:
	return battle_act_choice;

func battle_set_button(slot : int):
	battle_menu_button = _wrap_button_slot(slot)
	if battle_menu == BATTLE_MENU.BUTTON:
		_menu_selector.set_slot(battle_menu_button)
	emit_signal("BattleEvent", EVENT_TYPE.BUTTON_CHANGED, battle_menu_button, -1);
	
func battle_set_menu(menu : BATTLE_MENU):
	battle_menu = menu;
	match menu:
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
	
	_sync_selector_with_menu()
	battle_set_button(0);

func _process(_delta: float) -> void:
	if(battle_state == BATTLE_STATE.MENU):
		var UI = UImanager.get_ui();
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
		if(battle_menu == BATTLE_MENU.BUTTON):
			if(Input.is_action_just_pressed("ui_right")): _menu_move(1)
			if(Input.is_action_just_pressed("ui_left")): _menu_move(-1)
			if(Input.is_action_just_pressed("ui_accept")):
				match battle_menu_button:
					0:
						battle_set_menu(BATTLE_MENU.FIGHT_ENEMY_CHOICE);
					1:
						battle_set_menu(BATTLE_MENU.ACT_ENEMY_CHOICE);
					2:
						if !Global.player_data_items.is_empty():
							battle_set_menu(BATTLE_MENU.ITEM)
					3:
						battle_set_menu(BATTLE_MENU.MERCY)
		elif(battle_menu == BATTLE_MENU.FIGHT_ENEMY_CHOICE):
			if(Input.is_action_just_pressed("ui_right")): _menu_move(1)
			if(Input.is_action_just_pressed("ui_left")): _menu_move(-1)
			if(Input.is_action_just_pressed("ui_accept")):
				battle_set_menu(BATTLE_MENU.FIGHT_AIM);
			elif(Input.is_action_just_pressed("ui_cancel")):
				battle_set_menu(BATTLE_MENU.BUTTON);
		elif(battle_menu == BATTLE_MENU.FIGHT_AIM):
			pass;
		elif(battle_menu == BATTLE_MENU.ACT_ENEMY_CHOICE):
			if(Input.is_action_just_pressed("ui_right")): _menu_move(1)
			if(Input.is_action_just_pressed("ui_left")): _menu_move(-1)
			if(Input.is_action_just_pressed("ui_accept")):
				if battle_get_act_enemy_choice() != null and battle_get_act_enemy_choice().action_get_count() > 0:
					battle_set_menu(BATTLE_MENU.ACT_CHOICE)
			elif(Input.is_action_just_pressed("ui_cancel")):
				battle_set_menu(BATTLE_MENU.BUTTON);
		elif(battle_menu == BATTLE_MENU.ACT_CHOICE):
			if(Input.is_action_just_pressed("ui_right")): _menu_move(1)
			if(Input.is_action_just_pressed("ui_left")): _menu_move(-1)
			if(Input.is_action_just_pressed("ui_accept")):
				battle_set_menu(BATTLE_MENU.BUTTON)
			elif(Input.is_action_just_pressed("ui_cancel")):
				battle_set_menu(BATTLE_MENU.ACT_ENEMY_CHOICE);
		elif(battle_menu == BATTLE_MENU.ITEM):
			if(Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("ui_down")): _menu_move(1)
			if(Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_up")): _menu_move(-1)
			if(Input.is_action_just_pressed("ui_accept")):
				_use_selected_item()
			elif(Input.is_action_just_pressed("ui_cancel")):
				battle_set_menu(BATTLE_MENU.BUTTON)
		elif(battle_menu == BATTLE_MENU.MERCY):
			if(Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("ui_down")): _menu_move(1)
			if(Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_up")): _menu_move(-1)
			if(Input.is_action_just_pressed("ui_accept")):
				_confirm_mercy_choice()
			elif(Input.is_action_just_pressed("ui_cancel")):
				battle_set_menu(BATTLE_MENU.BUTTON)
