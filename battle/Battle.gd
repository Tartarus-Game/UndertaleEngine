class_name Battle extends Node

# ——— 灵魂位置常量 ———
const SOUL_BUTTON_OFFSET := Vector2(-38.0, 0.0)
const SOUL_MERCY_OFFSET := Vector2(-39.0, 0.0) # MERCY 按钮多偏移 1px
const SOUL_ITEM_X := 85.0
const SOUL_ITEM_BASE_Y := 288.0
const SOUL_ITEM_ROW_HEIGHT := 32.0

@onready var _box_typer = $BoxTyper
@onready var _battle_box = $BattleBox
@onready var fight_aim: BattleFightAim = $FightAim

@export var items: BattleOptionList
@export var enemy_selections: BattleEnemySelections
@export var ui_manager: BattleUIManager
@export var enemy_manager: EnemyManager
@export var soul: BattleSoulRed

enum EVENT_TYPE {
	MENU_CHANGED,
	BUTTON_CHANGED,
	FIGHT_ENEMY_CHOICE_CHANGED,
	ACT_ENEMY_CHOICE_CHANGED,
	ACT_CHOICE_CHANGED,
	ITEM_CHOICE_CHANGED,
	MERCY_CHOICE_CHANGED
}

enum BATTLE_MENU {
	BUTTON,
	FIGHT_ENEMY_CHOICE,
	FIGHT_AIM,
	FIGHT_ANIM,
	ACT_ENEMY_CHOICE,
	ACT_CHOICE,
	ITEM,
	MERCY_CHOICE,
	TEXT_DIALOGUE
}

enum BATTLE_STATE {
	MENU,
	DEFENDING
}

## 战斗事件信号（snake_case 符合 GDScript 规范）
signal battle_event(type: EVENT_TYPE, event: Variant, from: Variant)

var battle_menu: BATTLE_MENU = BATTLE_MENU.BUTTON
var _last_menu: BATTLE_MENU = BATTLE_MENU.BUTTON
var battle_state: BATTLE_STATE = BATTLE_STATE.MENU

var battle_fight_enemy_choice: int = 0
var battle_act_enemy_choice: int = 0
var battle_act_choice: int = 0
var battle_item_choice: int = 0
var battle_item_page: int = 0
var battle_menu_button: int = 0
var battle_mercy_choice: int = 0

# ——————————————————————————————————————————
#  选择器 Setter（带边界限制 + 灵魂定位 + 事件）
# ——————————————————————————————————————————

func battle_set_fight_enemy_choice(slot: int) -> void:
	var clamped := clampi(slot, 0, battle_get_enemy_count() - 1)
	battle_fight_enemy_choice = clamped
	enemy_selections.hide_info(false)
	enemy_selections.set_slot(clamped)
	soul.position = enemy_selections.selections[clamped].position
	battle_event.emit(EVENT_TYPE.FIGHT_ENEMY_CHOICE_CHANGED, clamped, -1)

func battle_set_act_enemy_choice(slot: int) -> void:
	var clamped := clampi(slot, 0, battle_get_enemy_count() - 1)
	battle_act_enemy_choice = clamped
	enemy_selections.hide_info(true)
	enemy_selections.set_slot(clamped)
	soul.position = enemy_selections.selections[clamped].position
	battle_event.emit(EVENT_TYPE.ACT_ENEMY_CHOICE_CHANGED, clamped, -1)

func battle_set_act_choice(slot: int) -> void:
	var size := battle_get_act_enemy_choice().action_get_count()
	var clamped := clampi(slot, 0, size - 1)
	battle_act_choice = clamped
	items.set_items(battle_get_act_enemy_choice().get_actions())
	items.set_slot(clamped)
	soul.position = Vector2(
		SOUL_ITEM_X,
		SOUL_ITEM_BASE_Y + SOUL_ITEM_ROW_HEIGHT * (clamped - items.page)
	)
	battle_event.emit(EVENT_TYPE.ACT_CHOICE_CHANGED, clamped, -1)

func battle_set_item_choice(slot: int) -> void:
	var size := Global.player_get_item_count()
	var clamped := clampi(slot, 0, size - 1)
	battle_item_choice = clamped
	while clamped < battle_item_page:
		battle_item_page -= 1
	while clamped > battle_item_page + 2:
		battle_item_page += 1
	items.set_slot(clamped)
	soul.position = Vector2(
		SOUL_ITEM_X,
		SOUL_ITEM_BASE_Y + SOUL_ITEM_ROW_HEIGHT * (clamped - battle_item_page)
	)
	battle_event.emit(EVENT_TYPE.ITEM_CHOICE_CHANGED, clamped, -1)

func battle_set_mercy_choice(slot: int) -> void:
	var options: Array[String] = ["Skip Turn"]
	var clamped := clampi(slot, 0, options.size() - 1)
	battle_mercy_choice = clamped
	items.set_items(options)
	items.set_slot(clamped)
	soul.position = Vector2(
		SOUL_ITEM_X,
		SOUL_ITEM_BASE_Y + SOUL_ITEM_ROW_HEIGHT * clamped
	)
	battle_event.emit(EVENT_TYPE.MERCY_CHOICE_CHANGED, clamped, -1)

func battle_set_button(slot: int) -> void:
	battle_event.emit(EVENT_TYPE.BUTTON_CHANGED, slot, -1)
	battle_menu_button = ui_manager.get_ui().get_button_slot()

# ——————————————————————————————————————————
#  菜单切换
# ——————————————————————————————————————————

func battle_set_menu(menu: BATTLE_MENU) -> void:
	battle_menu = menu
	match menu:
		BATTLE_MENU.BUTTON:
			_box_typer.visible = true
			for i in range(3):
				enemy_selections.hide_enemy(i, true)
			items.hide_all(true)
			
			_box_typer.clear_text()
			_box_typer.text_add("* 一些沙包在虚空中挡住了你的路", func(t): t.pause_text())
			_box_typer.next_text()
			
			if _last_menu == BATTLE_MENU.FIGHT_ENEMY_CHOICE or _last_menu == BATTLE_MENU.ACT_ENEMY_CHOICE or _last_menu == BATTLE_MENU.ACT_CHOICE or _last_menu == BATTLE_MENU.ITEM or _last_menu == BATTLE_MENU.MERCY_CHOICE:
				_box_typer.skip()
		BATTLE_MENU.FIGHT_ENEMY_CHOICE:
			_box_typer.skip()
			_box_typer.visible = false
			_refresh_enemy_selection_list()
			battle_set_fight_enemy_choice(battle_fight_enemy_choice)
		BATTLE_MENU.ACT_ENEMY_CHOICE:
			items.hide_all(true)
			_box_typer.skip()
			_box_typer.visible = false
			_refresh_enemy_selection_list()
			battle_set_act_enemy_choice(battle_act_enemy_choice)
		BATTLE_MENU.ACT_CHOICE:
			for i in range(3):
				enemy_selections.hide_enemy(i, true)
			battle_set_act_choice(0)
		BATTLE_MENU.FIGHT_AIM:
			for i in range(3):
				enemy_selections.hide_enemy(i, true)
			_box_typer.skip()
			_box_typer.visible = false
			fight_aim.start()
		BATTLE_MENU.ITEM:
			_box_typer.skip()
			_box_typer.visible = false
			items.set_items(Global.player_get_items())
			battle_set_item_choice(0)
		BATTLE_MENU.MERCY_CHOICE:
			_box_typer.skip()
			_box_typer.visible = false
			battle_set_mercy_choice(0)
		BATTLE_MENU.TEXT_DIALOGUE:
			for i in range(3):
				enemy_selections.hide_enemy(i, true)
			items.hide_all(true)
			_box_typer.visible = true
			soul.position = Vector2(-20, -20) # 隐藏灵魂
	battle_event.emit(EVENT_TYPE.MENU_CHANGED, menu, _last_menu)
	_last_menu = menu

## 刷新敌人列表显示（FIGHT 和 ACT 共用）
func _refresh_enemy_selection_list() -> void:
	var enemies := enemy_manager.battle_get_enemies()
	for i in range(3):
		if i < enemies.size():
			var enemy := enemies[i]
			enemy_selections.hide_enemy(i, false)
			var d = enemy.data
			enemy_selections.set_enemy_info(i, d.name, d.hp, d.hp_max)
		else:
			enemy_selections.hide_enemy(i, true)

## 开始一段等待玩家按Z确认的文本，确认后执行 next_action
func start_dialogue(text: String, next_action: Callable = Callable()) -> void:
	battle_set_menu(BATTLE_MENU.TEXT_DIALOGUE)
	_box_typer.clear_text()
	_box_typer.text_add("* " + text, func(t): t.pause_text())
	_box_typer.text_add("", func(t):
		t.pause = false
		if next_action.is_valid():
			next_action.call()
	)
	_box_typer.next_text()

# ——————————————————————————————————————————
#  Getter（转发 EnemyManager）
# ——————————————————————————————————————————

func battle_get_menu() -> BATTLE_MENU:
	return battle_menu

func battle_get_state() -> BATTLE_STATE:
	return battle_state

func battle_get_fight_enemy_choice() -> BattleEnemy:
	return battle_get_enemy(battle_fight_enemy_choice)

func battle_get_act_enemy_choice() -> BattleEnemy:
	return battle_get_enemy(battle_act_enemy_choice)

func battle_get_act_choice_number() -> int:
	return battle_act_choice

func battle_get_enemy(slot: int) -> BattleEnemy:
	return enemy_manager.battle_get_enemy(slot)

func battle_get_enemies() -> Array[BattleEnemy]:
	return enemy_manager.battle_get_enemies()

func battle_get_enemy_count() -> int:
	return enemy_manager.battle_get_enemy_count()

func battle_set_enemy(slot: int, packed: PackedScene) -> void:
	enemy_manager.battle_set_enemy(slot, packed)

# ——————————————————————————————————————————
#  生命周期
# ——————————————————————————————————————————

func _ready() -> void:
	BattleManager.active_battle = self
	battle_set_button(0)
	fight_aim.attack_finished.connect(_on_fight_aim_finished)

func _exit_tree() -> void:
	if BattleManager.active_battle == self:
		BattleManager.active_battle = null

var _box_tween: Tween

func shrink_box() -> void:
	_box_typer.visible = false
	_box_typer.clear_text()
	if _box_tween and _box_tween.is_valid():
		_box_tween.kill()

	_box_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel(true)
	_box_tween.tween_property(_battle_box, "size", Vector2(140, 140), 0.3)
	_box_tween.tween_property(soul, "position", Vector2(320, 320), 0.3)
	await _box_tween.finished

func restore_box() -> void:
	if _box_tween and _box_tween.is_valid():
		_box_tween.kill()

	_box_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_box_tween.tween_property(_battle_box, "size", Vector2(573, 140), 0.3)
	await _box_tween.finished

## 灵魂跟随 BUTTON 菜单中的按钮位置（每帧更新以支持按钮动画）
func _process(_delta: float) -> void:
	if battle_state == BATTLE_STATE.MENU and battle_menu == BATTLE_MENU.BUTTON:
		var ui := ui_manager.get_ui()
		var offset := SOUL_MERCY_OFFSET if battle_menu_button == 3 else SOUL_BUTTON_OFFSET
		soul.position = ui.get_button(battle_menu_button).global_position + offset

# ——————————————————————————————————————————
#  输入处理（拆分到独立方法）
# ——————————————————————————————————————————

func _on_fight_aim_finished(mult: float) -> void:
	var enemy = battle_get_fight_enemy_choice()
	# 简单公式: 基础攻击力 * 伤害倍率
	var dmg = enemy.take_damage(20.0 * mult)
	print("造成了伤害:", dmg, " 倍率:", mult)
	# 等待伤害显示动画播完
	await get_tree().create_timer(2.2).timeout
	
	# 检查敌人是否死亡
	if enemy.data and enemy.data.hp <= 0:
		enemy.retire()
		enemy.defeated.connect(func():
			enemy_manager.remove_enemy(enemy)
			# 所有敌人都被击败
			if battle_get_enemy_count() == 0:
				print("所有敌人被击败！战斗胜利！")
				# TODO: 胜利流程
				return
			BattleManager.start_enemy_turn()
		)
		return
	
	BattleManager.start_enemy_turn()


func _unhandled_input(event: InputEvent) -> void:
	if battle_state != BATTLE_STATE.MENU:
		return
	match battle_menu:
		BATTLE_MENU.BUTTON:
			_handle_button_input(event)
		BATTLE_MENU.FIGHT_ENEMY_CHOICE:
			_handle_fight_enemy_input(event)
		BATTLE_MENU.FIGHT_AIM:
			_handle_fight_aim_input(event)
		BATTLE_MENU.ACT_ENEMY_CHOICE:
			_handle_act_enemy_input(event)
		BATTLE_MENU.ACT_CHOICE:
			_handle_act_choice_input(event)
		BATTLE_MENU.ITEM:
			_handle_item_input(event)
		BATTLE_MENU.MERCY_CHOICE:
			_handle_mercy_choice_input(event)

func _handle_fight_aim_input(event: InputEvent) -> void:
	fight_aim.handle_input(event)

func _handle_button_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		match battle_menu_button:
			0: battle_set_menu(BATTLE_MENU.FIGHT_ENEMY_CHOICE)
			1: battle_set_menu(BATTLE_MENU.ACT_ENEMY_CHOICE)
			2:
				if Global.player_get_item_count() > 0:
					battle_set_menu(BATTLE_MENU.ITEM)
			3:
				battle_set_menu(BATTLE_MENU.MERCY_CHOICE)

func _handle_fight_enemy_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		battle_set_fight_enemy_choice(battle_fight_enemy_choice + 1)
	elif event.is_action_pressed("ui_up"):
		battle_set_fight_enemy_choice(battle_fight_enemy_choice - 1)
	elif event.is_action_pressed("ui_accept"):
		battle_set_menu(BATTLE_MENU.FIGHT_AIM)
	elif event.is_action_pressed("ui_cancel"):
		battle_set_menu(BATTLE_MENU.BUTTON)

func _handle_act_enemy_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		battle_set_act_enemy_choice(battle_act_enemy_choice + 1)
	elif event.is_action_pressed("ui_up"):
		battle_set_act_enemy_choice(battle_act_enemy_choice - 1)
	elif event.is_action_pressed("ui_accept"):
		battle_set_menu(BATTLE_MENU.ACT_CHOICE)
	elif event.is_action_pressed("ui_cancel"):
		battle_set_menu(BATTLE_MENU.BUTTON)

func _handle_act_choice_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		battle_set_act_choice(battle_act_choice - 1)
	elif event.is_action_pressed("ui_down"):
		battle_set_act_choice(battle_act_choice + 1)
	elif event.is_action_pressed("ui_accept"):
		var enemy := battle_get_act_enemy_choice()
		# 具体的行动逻辑与文本显示由 Enemy 内部的 action_call 决定，包括换到敌方回合
		enemy.action_call(battle_act_choice)
	elif event.is_action_pressed("ui_cancel"):
		battle_set_menu(BATTLE_MENU.ACT_ENEMY_CHOICE)

func _handle_item_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		battle_set_item_choice(battle_item_choice - 1)
	elif event.is_action_pressed("ui_down"):
		battle_set_item_choice(battle_item_choice + 1)
	elif event.is_action_pressed("ui_accept"):
		print("Used item slot: " + str(battle_item_choice))
		# NOTE: Item consuming logic goes here (e.g., healing)
		battle_set_menu(BATTLE_MENU.BUTTON)
		BattleManager.start_enemy_turn()
	elif event.is_action_pressed("ui_cancel"):
		battle_set_menu(BATTLE_MENU.BUTTON)

func _handle_mercy_choice_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		battle_set_mercy_choice(battle_mercy_choice - 1)
	elif event.is_action_pressed("ui_down"):
		battle_set_mercy_choice(battle_mercy_choice + 1)
	elif event.is_action_pressed("ui_accept"):
		print("Player selected MERCY option: " + str(battle_mercy_choice))
		# Assume 0 is "Skip Turn"
		battle_set_menu(BATTLE_MENU.BUTTON)
		BattleManager.start_enemy_turn()
	elif event.is_action_pressed("ui_cancel"):
		battle_set_menu(BATTLE_MENU.BUTTON)
