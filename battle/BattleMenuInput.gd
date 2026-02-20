class_name BattleMenuInput

func handle_event(battle: Battle, event: InputEvent) -> void:
	if battle == null:
		return

	var menu := battle.battle_get_menu()
	if menu == Battle.BATTLE_MENU.BUTTON:
		if event.is_action_pressed("ui_accept"):
			_handle_button_accept(battle)
		return

	if menu == Battle.BATTLE_MENU.FIGHT_ENEMY_CHOICE:
		if event.is_action_pressed("ui_down"):
			battle.battle_set_fight_enemy_choice(battle_fight_next(battle, 1))
		elif event.is_action_pressed("ui_up"):
			battle.battle_set_fight_enemy_choice(battle_fight_next(battle, -1))
		elif event.is_action_pressed("ui_accept"):
			battle.battle_set_menu(Battle.BATTLE_MENU.FIGHT_AIM)
		elif event.is_action_pressed("ui_cancel"):
			battle.battle_set_menu(Battle.BATTLE_MENU.BUTTON)
		return

	if menu == Battle.BATTLE_MENU.ACT_ENEMY_CHOICE:
		if event.is_action_pressed("ui_down"):
			battle.battle_set_act_enemy_choice(battle_act_enemy_next(battle, 1))
		elif event.is_action_pressed("ui_up"):
			battle.battle_set_act_enemy_choice(battle_act_enemy_next(battle, -1))
		elif event.is_action_pressed("ui_accept"):
			battle.battle_set_menu(Battle.BATTLE_MENU.ACT_CHOICE)
		elif event.is_action_pressed("ui_cancel"):
			battle.battle_set_menu(Battle.BATTLE_MENU.BUTTON)
		return

	if menu == Battle.BATTLE_MENU.ACT_CHOICE:
		if event.is_action_pressed("ui_right"):
			_act_move(battle, 1)
		elif event.is_action_pressed("ui_left"):
			_act_move(battle, -1)
		elif event.is_action_pressed("ui_up"):
			_act_move(battle, -2)
		elif event.is_action_pressed("ui_down"):
			_act_move(battle, 2)
		elif event.is_action_pressed("ui_cancel"):
			battle.battle_set_menu(Battle.BATTLE_MENU.ACT_ENEMY_CHOICE)
		return

	if menu == Battle.BATTLE_MENU.ITEM:
		if event.is_action_pressed("ui_up"):
			battle.battle_set_item_choice(battle_item_next(battle, -1))
		elif event.is_action_pressed("ui_down"):
			battle.battle_set_item_choice(battle_item_next(battle, 1))
		elif event.is_action_pressed("ui_cancel"):
			battle.battle_set_menu(Battle.BATTLE_MENU.BUTTON)
		return

func _handle_button_accept(battle: Battle) -> void:
	var slot := battle.battle_get_button_slot()
	if slot == 0:
		battle.battle_set_menu(Battle.BATTLE_MENU.FIGHT_ENEMY_CHOICE)
	elif slot == 1:
		battle.battle_set_menu(Battle.BATTLE_MENU.ACT_ENEMY_CHOICE)
	elif slot == 2:
		if Global.player_get_item_count() > 0:
			battle.battle_set_menu(Battle.BATTLE_MENU.ITEM)

func battle_fight_next(battle: Battle, delta: int) -> int:
	return battle.battle_get_fight_enemy_choice_number() + delta

func battle_act_enemy_next(battle: Battle, delta: int) -> int:
	return battle.battle_get_act_enemy_choice_number() + delta

func battle_item_next(battle: Battle, delta: int) -> int:
	return battle.battle_get_item_choice_number() + delta

func _act_move(battle: Battle, delta: int) -> void:
	var next_slot := battle.battle_get_act_choice_number() + delta
	battle.battle_set_act_choice(next_slot)
