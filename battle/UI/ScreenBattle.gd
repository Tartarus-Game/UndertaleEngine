class_name ScreenBattle extends Screen

@onready var player_info_node = $PlayerInfo
@onready var button_manager = $BattleButtonManager

@export var button_choice_sound: AudioStream
@export var button_accept: AudioStream
@export var soul: BattleSoulRed
@export var battle: Battle

func _ready() -> void:
	_register_buttons()
	ScreenManager.register_screen(self )
	ScreenManager.set_active_screen(self )

func _exit_tree() -> void:
	ScreenManager.unregister_screen(self )

func _register_buttons() -> void:
	clear_buttons()
	for i in range(4):
		add_button(
			button_manager.get_button(i),
			Callable(),
			Callable(self , "_on_button_selected").bind(i),
			Callable()
		)

func handle_input(event: InputEvent) -> void:
	if not is_active():
		return
	if not _can_navigate_buttons():
		return
	if event.is_action_pressed("ui_left"):
		navigate(-1)
	elif event.is_action_pressed("ui_right"):
		navigate(1)

func _can_navigate_buttons() -> bool:
	if battle == null:
		return false
	return battle.battle_get_menu() == Battle.BATTLE_MENU.BUTTON

func _on_button_selected(slot: int) -> void:
	if battle == null:
		return
	battle.battle_set_button(slot)

func get_button(slot: int) -> Node:
	return button_manager.get_button(slot)

func tween_create() -> Tween:
	return create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func set_button_slot(slot: int) -> void:
	AudioManager.play_sound_with_pitch(button_choice_sound, 0.8)
	button_manager.button_set(slot)

func get_button_slot() -> int:
	return get_active_button_index()

## 响应 Battle.battle_event 信号
func _on_battle_battle_event(type: Battle.EVENT_TYPE, event: Variant, _from: Variant) -> void:
	match type:
		Battle.EVENT_TYPE.BUTTON_CHANGED:
			sync_active_index(event)
			set_button_slot(event)
		Battle.EVENT_TYPE.MENU_CHANGED:
			AudioManager.play_sound_with_pitch(button_accept, 1.0)
		Battle.EVENT_TYPE.FIGHT_ENEMY_CHOICE_CHANGED, \
		Battle.EVENT_TYPE.ACT_ENEMY_CHOICE_CHANGED, \
		Battle.EVENT_TYPE.ACT_CHOICE_CHANGED, \
		Battle.EVENT_TYPE.ITEM_CHOICE_CHANGED:
			AudioManager.play_sound_with_pitch(button_choice_sound, 1.0)
