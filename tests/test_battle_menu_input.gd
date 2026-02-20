extends SceneTree

var _passed := true

class StubBattle:
	var menu := Battle.BATTLE_MENU.BUTTON
	var button_slot := 0
	var fight_enemy_choice := 0
	var act_enemy_choice := 0
	var act_choice := 0
	var item_choice := 0
	var item_count := 3
	var enemy_count := 2

	func battle_get_menu() -> int:
		return menu

	func battle_get_button_slot() -> int:
		return button_slot

	func battle_set_menu(next_menu: int) -> void:
		menu = next_menu

	func battle_get_enemy_count() -> int:
		return enemy_count

	func battle_set_fight_enemy_choice(slot: int) -> void:
		fight_enemy_choice = slot

	func battle_get_fight_enemy_choice_number() -> int:
		return fight_enemy_choice

	func battle_set_act_enemy_choice(slot: int) -> void:
		act_enemy_choice = slot

	func battle_get_act_enemy_choice_number() -> int:
		return act_enemy_choice

	func battle_set_act_choice(slot: int) -> void:
		act_choice = slot

	func battle_get_act_choice_number() -> int:
		return act_choice

	func battle_set_item_choice(slot: int) -> void:
		item_choice = slot

	func battle_get_item_choice_number() -> int:
		return item_choice

	func battle_get_act_enemy_choice():
		return self

	func action_get_count() -> int:
		return 4

func _init() -> void:
	_run()
	if _passed:
		quit(0)
	else:
		quit(1)

func _run() -> void:
	_test_button_accept_switches_to_fight_enemy_choice()
	_test_enemy_choice_navigation()
	_test_enemy_choice_does_not_underflow()
	_test_enemy_choice_does_not_overflow()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_passed = false
		push_error(message)

func _make_action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event

func _test_button_accept_switches_to_fight_enemy_choice() -> void:
	var battle := StubBattle.new()
	var router := BattleMenuInput.new()
	var event := _make_action("ui_accept")
	router.handle_event(battle, event)
	_assert(
		battle.battle_get_menu() == Battle.BATTLE_MENU.FIGHT_ENEMY_CHOICE,
		"accept on BUTTON slot 0 should switch to FIGHT_ENEMY_CHOICE"
	)

func _test_enemy_choice_navigation() -> void:
	var battle := StubBattle.new()
	var router := BattleMenuInput.new()
	battle.battle_set_menu(Battle.BATTLE_MENU.FIGHT_ENEMY_CHOICE)
	router.handle_event(battle, _make_action("ui_down"))
	_assert(battle.fight_enemy_choice == 1, "down should advance enemy choice")
	router.handle_event(battle, _make_action("ui_up"))
	_assert(battle.fight_enemy_choice == 0, "up should decrease enemy choice")

func _test_enemy_choice_does_not_underflow() -> void:
	var battle := StubBattle.new()
	var router := BattleMenuInput.new()
	battle.battle_set_menu(Battle.BATTLE_MENU.FIGHT_ENEMY_CHOICE)
	# Already at 0; pressing up should clamp, not go negative
	router.handle_event(battle, _make_action("ui_up"))
	_assert(battle.fight_enemy_choice >= 0, "enemy choice should not go below 0")

func _test_enemy_choice_does_not_overflow() -> void:
	var battle := StubBattle.new()
	var router := BattleMenuInput.new()
	battle.battle_set_menu(Battle.BATTLE_MENU.FIGHT_ENEMY_CHOICE)
	# enemy_count is 2 (indices 0..1); advance past the last
	router.handle_event(battle, _make_action("ui_down"))
	router.handle_event(battle, _make_action("ui_down"))
	_assert(
		battle.fight_enemy_choice < battle.enemy_count,
		"enemy choice should not exceed enemy_count - 1"
	)
