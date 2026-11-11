class_name BattleUI extends Screen

@onready var player_info_node = $PlayerInfo;
@onready var button_manager = $BattleButtonManager;

@export var button_choice_sound : AudioStream;
@export var button_accept : AudioStream;
@export var soul : BattleSoulRed;
@export var battle : Battle;

var fight_enemy_slot : int = 0;
var act_enemy_slot : int = 0;
var act_slot : int = 0;
var item_slot : int = 0;
var karma_bar: ColorRect

func _ready() -> void:
	karma_bar = ColorRect.new()
	karma_bar.color = Color(0.8, 0.1, 0.8)
	karma_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$PlayerInfo/HPMax.add_child(karma_bar)
	Global.player_hp_changed.connect(_update_hp)
	Global.player_stats_changed.connect(_update_stats)
	_update_hp(int(Global.player_data.hp), int(Global.player_data.hp_max))
	_update_stats()
	for index in range(4):
		add_button(get_button(index), Callable(), _select_main_button.bind(index), _activate_main_button.bind(index))
	set_active(true)

func _select_main_button(index: int) -> void:
	battle.battle_set_button(index)

func _activate_main_button(index: int) -> void:
	battle.choose_main_button(index)

func _update_hp(hp: int, maximum: int) -> void:
	$PlayerInfo/Label.text = "%d / %d" % [hp, maximum]
	$PlayerInfo/HPMax/HP.size.x = 25.0 * float(hp) / float(maxi(maximum, 1))
	_update_karma()

func _update_stats() -> void:
	$PlayerInfo/Name.text = str(Global.player_data.name)
	$PlayerInfo/LV.text = "LV %d" % int(Global.player_data.lv)
	_update_karma()


func _update_karma() -> void:
	if not is_instance_valid(karma_bar): return
	var maximum := maxf(float(Global.player_data.hp_max), 1.0)
	var hp := float(Global.player_data.hp)
	var kr := minf(float(Global.player_data.kr), hp)
	karma_bar.position = Vector2(25.0 * (hp - kr) / maximum, 0)
	karma_bar.size = Vector2(25.0 * kr / maximum, 21.0)
	karma_bar.visible = kr > 0.0


func get_button(slot : int):
	return button_manager.get_button(slot);

func tween_create():
	return create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT);
	
func set_button_slot(slot : int):
	AudioManager.play_sound_with_pitch(button_choice_sound, 0.8);
	button_manager.button_set(slot);

func get_button_slot():
	return button_manager.get_button_slot();


func _on_battle_battle_event(TYPE: Battle.EVENT_TYPE, EVENT: Variant, _FROM: Variant) -> void:
	match TYPE:
		Battle.EVENT_TYPE.BUTTON_CHANGED:
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
				Battle.BATTLE_MENU.ITEM, Battle.BATTLE_MENU.ITEM_COMMAND, Battle.BATTLE_MENU.ITEM_INFO, Battle.BATTLE_MENU.MERCY:
					AudioManager.play_sound_with_pitch(button_accept, 1);
		Battle.EVENT_TYPE.FIGHT_ENEMY_CHOICE_CHANGED:
			if(EVENT != fight_enemy_slot):
				AudioManager.play_sound_with_pitch(button_choice_sound, 1);
			fight_enemy_slot = EVENT;
		Battle.EVENT_TYPE.ACT_ENEMY_CHOICE_CHANGED:
			if(EVENT != act_enemy_slot):
				AudioManager.play_sound_with_pitch(button_choice_sound, 1);
			act_enemy_slot = EVENT;
		Battle.EVENT_TYPE.ACT_CHOICE_CHANGED:
			if(EVENT != act_slot):
				AudioManager.play_sound_with_pitch(button_choice_sound, 1);
			act_slot = EVENT;
		Battle.EVENT_TYPE.ITEM_CHOICE_CHANGED:
			if(EVENT != item_slot):
				AudioManager.play_sound_with_pitch(button_choice_sound, 1);
			item_slot = EVENT;
