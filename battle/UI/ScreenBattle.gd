class_name ScreenBattle extends Screen

@onready var player_info_node = $PlayerInfo;
@onready var button_manager = $BattleButtonManager;

@export var button_choice_sound: AudioStream;
@export var button_accept: AudioStream;
@export var soul: BattleSoulRed;
@export var battle: Battle;


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


func _on_button_selected(slot: int) -> void:
	if battle == null:
		return
	battle.battle_set_button(slot)


func get_button(slot: int):
	return button_manager.get_button(slot);


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
			if EVENT in [
				Battle.BATTLE_MENU.BUTTON,
				Battle.BATTLE_MENU.FIGHT_ENEMY_CHOICE,
				Battle.BATTLE_MENU.ACT_ENEMY_CHOICE,
				Battle.BATTLE_MENU.ACT_CHOICE,
				Battle.BATTLE_MENU.ITEM
			]:
				AudioManager.play_sound_with_pitch(button_accept, 1);
		Battle.EVENT_TYPE.FIGHT_ENEMY_CHOICE_CHANGED:
			AudioManager.play_sound_with_pitch(button_choice_sound, 1);
		Battle.EVENT_TYPE.ACT_ENEMY_CHOICE_CHANGED:
			AudioManager.play_sound_with_pitch(button_choice_sound, 1);
		Battle.EVENT_TYPE.ACT_CHOICE_CHANGED:
			AudioManager.play_sound_with_pitch(button_choice_sound, 1);
		Battle.EVENT_TYPE.ITEM_CHOICE_CHANGED:
			AudioManager.play_sound_with_pitch(button_choice_sound, 1);
