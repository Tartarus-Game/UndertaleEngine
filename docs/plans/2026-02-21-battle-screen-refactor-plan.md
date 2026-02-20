# Battle Screen Alignment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Align battle menu input with `/gui` Screen/ScreenManager patterns by routing input through `ScreenBattle` and a pure input router, keeping behavior identical.

**Architecture:** Add a small, testable `BattleMenuInput` router that translates `InputEvent` into calls on `Battle`. `ScreenBattle` becomes the sole input entry point and delegates to the router for non-button menus while continuing to use `Screen` navigation for the button row.

**Tech Stack:** Godot 4, GDScript, existing `/gui` Screen + ScreenManager, tests in `tests/*.gd`.

---

### Task 1: Add failing unit tests for the menu input router

**Files:**
- Create: `tests/test_battle_menu_input.gd`

**Step 1: Write the failing test**

```gdscript
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
```

**Step 2: Run test to verify it fails**

Run: `godot --headless --script tests/test_battle_menu_input.gd`

Expected: FAIL with "BattleMenuInput not found" or missing method errors.

---

### Task 2: Implement the BattleMenuInput router and required getters

**Files:**
- Create: `battle/BattleMenuInput.gd`
- Modify: `battle/Battle.gd`

**Step 1: Write minimal implementation**

```gdscript
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
```

**Step 1b: Add small getters in Battle.gd**

```gdscript
func battle_get_button_slot() -> int:
	return battle_menu_button

func battle_get_fight_enemy_choice_number() -> int:
	return battle_fight_enemy_choice

func battle_get_act_enemy_choice_number() -> int:
	return battle_act_enemy_choice

func battle_get_item_choice_number() -> int:
	return battle_item_choice
```

**Step 2: Run test to verify it passes**

Run: `godot --headless --script tests/test_battle_menu_input.gd`

Expected: PASS (exit code 0).

---

### Task 3: Route battle input through ScreenBattle and remove polling

**Files:**
- Modify: `battle/UI/ScreenBattle.gd`
- Modify: `battle/Battle.gd`

**Step 1: Update ScreenBattle to use the router**

```gdscript
@export var menu_input: BattleMenuInput

func _ready() -> void:
	if menu_input == null:
		menu_input = BattleMenuInput.new()
	_register_buttons()
	ScreenManager.register_screen(self)
	ScreenManager.set_active_screen(self)

func handle_input(event: InputEvent) -> void:
	if not is_active():
		return
	if battle == null:
		return
	if battle.battle_get_menu() == Battle.BATTLE_MENU.BUTTON:
		Screen.handle_input(event)
		if event.is_action_pressed("ui_accept"):
			menu_input.handle_event(battle, event)
		return
	menu_input.handle_event(battle, event)
```

**Step 2: Remove polling input in Battle._process**

```gdscript
func _process(_delta: float) -> void:
	if battle_state == BATTLE_STATE.MENU and battle_menu == BATTLE_MENU.BUTTON:
		var UI = UImanager.get_ui()
		match battle_menu_button:
			0, 1, 2:
				soul.position = UI.get_button(battle_menu_button).global_position + Vector2(-38, 0)
			3:
				soul.position = UI.get_button(battle_menu_button).global_position + Vector2(-39, 0)
```

**Step 3: Run tests**

Run: `godot --headless --script tests/test_screen_groups.gd`
Expected: PASS

Run: `godot --headless --script tests/test_battle_menu_input.gd`
Expected: PASS

**Step 4: Manual verification**

- Run the battle test scene (e.g., `overworld/test_level/`), confirm:
  - Button row navigation left/right still works and updates the soul.
  - Accept on FIGHT/ACT/ITEM transitions to the right menu.
  - Enemy selection up/down moves between enemies with sound.
  - ACT grid navigation (left/right/up/down) updates selection.
  - ITEM list scrolls and cancel returns to the button row.

---

### Task 4: Commit

**Step 1: Commit**

```bash
git add battle/Battle.gd battle/UI/ScreenBattle.gd battle/BattleMenuInput.gd tests/test_battle_menu_input.gd docs/plans/2026-02-21-battle-screen-refactor-*.md
git commit -m "refactor: route battle menu input through Screen"
```
