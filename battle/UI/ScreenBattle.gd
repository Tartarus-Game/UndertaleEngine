class_name ScreenBattle extends Screen

@onready var player_info_node = $PlayerInfo;
@onready var button_manager = $BattleButtonManager;

@export var button_choice_sound: AudioStream;
@export var button_accept: AudioStream;
@export var soul: BattleSoulRed;
@export var battle: Battle;

var fight_enemy_slot: int = 0;
var act_enemy_slot: int = 0;
var act_slot: int = 0;
var item_slot: int = 0;

@export var menu_input: BattleMenuInput

func _ready() -> void:
	if menu_input == null:
		menu_input = BattleMenuInput.new()
	_register_buttons()
	ScreenManager.register_screen(self )
	ScreenManager.set_active_screen(self )

func _exit_tree() -> void:
	ScreenManager.unregister_screen(self )

func _register_buttons() -> void:
	clear_buttons()
	add_button(
		button_manager.get_button(0),
		Callable(),
		Callable(self , "_on_button_selected").bind(0),
		Callable()
	)
	add_button(
		button_manager.get_button(1),
		Callable(),
		Callable(self , "_on_button_selected").bind(1),
		Callable()
	)
	add_button(
		button_manager.get_button(2),
		Callable(),
		Callable(self , "_on_button_selected").bind(2),
		Callable()
	)
	add_button(
		button_manager.get_button(3),
		Callable(),
		Callable(self , "_on_button_selected").bind(3),
		Callable()
	)

func handle_input(event: InputEvent) -> void:
	if not is_active():
		return
	if battle == null:
		return
	if battle.battle_get_menu() == Battle.BATTLE_MENU.BUTTON:
		super.handle_input(event)
		if event.is_action_pressed("ui_accept"):
			menu_input.handle_event(battle, event)
		return
	menu_input.handle_event(battle, event)

func _can_navigate_buttons() -> bool:
	if battle == null:
		return false
	return battle.battle_get_menu() == Battle.BATTLE_MENU.BUTTON

func _on_button_selected(slot: int) -> void:
	if battle == null:
		return
	battle.battle_set_button(slot)


func get_button(slot: int):
	return button_manager.get_button(slot);

func tween_create():
	return create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT);
	
func set_button_slot(slot: int):
	AudioManager.play_sound_with_pitch(button_choice_sound, 0.8);
	button_manager.button_set(slot);

func get_button_slot():
	return get_active_button_index();


func _on_battle_battle_event(TYPE: Battle.EVENT_TYPE, EVENT: Variant, _FROM: Variant) -> void:
	match TYPE:
		Battle.EVENT_TYPE.BUTTON_CHANGED:
			sync_active_index(EVENT)
			set_button_slot(EVENT);
		Battle.EVENT_TYPE.MENU_CHANGED:
			match EVENT:
				Battle.BATTLE_MENU.BUTTON:
					AudioManager.play_sound_with_pitch(button_accept, 1);
				Battle.BATTLE_MENU.FIGHT_ENEMY_CHOICE:
					AudioManager.play_sound_with_pitch(button_accept, 1);
				Battle.BATTLE_MENU.ACT_ENEMY_CHOICE:
					AudioManager.play_sound_with_pitch(button_accept, 1);
				Battle.BATTLE_MENU.ACT_CHOICE:
					AudioManager.play_sound_with_pitch(button_accept, 1);
				Battle.BATTLE_MENU.ITEM:
					AudioManager.play_sound_with_pitch(button_accept, 1);
		Battle.EVENT_TYPE.FIGHT_ENEMY_CHOICE_CHANGED:
			if (EVENT != fight_enemy_slot):
				AudioManager.play_sound_with_pitch(button_choice_sound, 1);
			fight_enemy_slot = EVENT;
		Battle.EVENT_TYPE.ACT_ENEMY_CHOICE_CHANGED:
			if (EVENT != act_enemy_slot):
				AudioManager.play_sound_with_pitch(button_choice_sound, 1);
			act_enemy_slot = EVENT;
		Battle.EVENT_TYPE.ACT_CHOICE_CHANGED:
			if (EVENT != act_slot):
				AudioManager.play_sound_with_pitch(button_choice_sound, 1);
			act_slot = EVENT;
		Battle.EVENT_TYPE.ITEM_CHOICE_CHANGED:
			if (EVENT != item_slot):
				AudioManager.play_sound_with_pitch(button_choice_sound, 1);
			item_slot = EVENT;
