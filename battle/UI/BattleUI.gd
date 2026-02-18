class_name BattleUI extends Control

@onready var player_info_node = $PlayerInfo;
@onready var button_manager = $BattleButtonManager;

@export var button_choice_sound : AudioStream;
@export var button_accept : AudioStream;
@export var soul : BattleSoulRed;
@export var battle : Battle;

var fight_enemy_slot : int = 0;
var act_enemy_slot : int = 0;
var act_slot : int = 0;

func get_button(slot : int):
	return button_manager.get_button(slot);

func tween_create():
	return create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT);
	
func set_button_slot(slot : int):
	AudioManager.play_sound_with_pitch(button_choice_sound, 0.8);
	button_manager.button_set(slot);

func get_button_slot():
	return button_manager.get_button_slot();


func _on_battle_battle_event(TYPE: Battle.EVENT_TYPE, EVENT: Variant, FROM: Variant) -> void:
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
				Battle.BATTLE_MENU.ITEM:
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
