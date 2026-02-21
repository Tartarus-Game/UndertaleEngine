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

func _process(delta: float) -> void:
	if not is_active():
		return
	_update_player_info()

func _update_player_info() -> void:
	if not player_info_node:
		return
		
	var hp = Global.player_data.get("hp", 20)
	var hp_max = Global.player_data.get("hp_max", 20)
	var lv = Global.player_data.get("lv", 1)
	var player_name = Global.player_data.get("name", "CHARA")
	
	player_info_node.get_node("Name").text = player_name
	player_info_node.get_node("LV").text = "LV " + str(lv)
	
	# 原作中 1 HP = 1.25 px 的宽度（例如 20 HP_MAX 为 25px）
	var max_bar_width = float(hp_max) * 1.25
	var cur_bar_width = float(hp) * 1.25
	
	var hp_max_rect = player_info_node.get_node("HPMax") as ColorRect
	var hp_rect = hp_max_rect.get_node("HP") as ColorRect
	var hp_label = player_info_node.get_node("Label") as Label
	
	hp_max_rect.size.x = max_bar_width
	hp_rect.size.x = cur_bar_width
	
	# 文字的横坐标要跟随血条的变化而推移
	hp_label.position.x = hp_max_rect.position.x + max_bar_width + 15.0
	
	# 不足两位数时为了排版补上空格
	var hp_str = str(int(hp))
	var hp_max_str = str(int(hp_max))
	if hp < 10: hp_str = "0" + hp_str
	
	hp_label.text = hp_str + " / " + hp_max_str

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
	return battle.battle_get_state() == Battle.BATTLE_STATE.MENU and battle.battle_get_menu() == Battle.BATTLE_MENU.BUTTON

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
