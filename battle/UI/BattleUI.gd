class_name BattleUI extends Control

@onready var player_info_node = $PlayerInfo;
@onready var button_manager = $BattleButtonManager;
@onready var menu_renderer = $BattleMenuRenderer;

@export var button_choice_sound : AudioStream;
@export var button_accept : AudioStream;
@export var soul : BattleSoulRed;
@export var battle : Battle;

var fight_enemy_slot : int = 0;
var act_enemy_slot : int = 0;
var act_slot : int = 0;
var item_slot : int = 0;
var mercy_slot : int = 0;

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
					menu_renderer.hide_menu()
				
				Battle.BATTLE_MENU.FIGHT_ENEMY_CHOICE:
					AudioManager.play_sound_with_pitch(button_accept, 1);
					var opts = []
					for enemy in battle.battle_get_enemys():
						var color = Color(1,1,1,1) if enemy.get_spareable() else Color.WHITE
						opts.append({"text": enemy.get_enemy_name(), "color": color})
					menu_renderer.show_menu(opts, battle.battle_fight_enemy_choice)
				
				Battle.BATTLE_MENU.ACT_ENEMY_CHOICE:
					AudioManager.play_sound_with_pitch(button_accept, 1);
					var opts = []
					for enemy in battle.battle_get_enemys():
						var color = Color(1,1,0) if enemy.get_spareable() else Color.WHITE
						opts.append({"text": enemy.get_enemy_name(), "color": color})
					menu_renderer.show_menu(opts, battle.battle_act_enemy_choice)
				
				Battle.BATTLE_MENU.ACT_CHOICE:
					AudioManager.play_sound_with_pitch(button_accept, 1);
					var enemy = battle.battle_get_act_enemy_choice()
					var opts = []
					if enemy:
						for action in enemy.get_actions():
							opts.append(action[0])
					menu_renderer.show_menu(opts, battle.battle_act_choice)
				
				Battle.BATTLE_MENU.ITEM:
					AudioManager.play_sound_with_pitch(button_accept, 1);
					var opts = []
					for item in Global.player_data_items:
						if typeof(item) == TYPE_OBJECT and item.has_method("name"):
							opts.append(item.name())
						else:
							opts.append(str(item))
					menu_renderer.show_menu(opts, battle.battle_item_choice)
				
				Battle.BATTLE_MENU.MERCY:
					AudioManager.play_sound_with_pitch(button_accept, 1);
					var spare_color = Color.WHITE
					for enemy in battle.battle_get_enemys():
						if enemy.get_spareable():
							spare_color = Color(1,1,0)
							break
					menu_renderer.show_menu([{"text": "Spare", "color": spare_color}, "Flee"], battle.battle_mercy_choice)
				
				Battle.BATTLE_MENU.FIGHT_AIM, Battle.BATTLE_MENU.FIGHT_ANIM, Battle.BATTLE_MENU.FIGHT_DAMAGE:
					menu_renderer.hide_menu()
		Battle.EVENT_TYPE.FIGHT_ENEMY_CHOICE_CHANGED:
			if(EVENT != fight_enemy_slot):
				AudioManager.play_sound_with_pitch(button_choice_sound, 1);
			fight_enemy_slot = EVENT;
			menu_renderer.set_selected(EVENT)
		
		Battle.EVENT_TYPE.ACT_ENEMY_CHOICE_CHANGED:
			if(EVENT != act_enemy_slot):
				AudioManager.play_sound_with_pitch(button_choice_sound, 1);
			act_enemy_slot = EVENT;
			menu_renderer.set_selected(EVENT)
		
		Battle.EVENT_TYPE.ACT_CHOICE_CHANGED:
			if(EVENT != act_slot):
				AudioManager.play_sound_with_pitch(button_choice_sound, 1);
			act_slot = EVENT;
			menu_renderer.set_selected(EVENT)
		
		Battle.EVENT_TYPE.ITEM_CHOICE_CHANGED:
			if(EVENT != item_slot):
				AudioManager.play_sound_with_pitch(button_choice_sound, 1);
			item_slot = EVENT;
			menu_renderer.set_selected(EVENT)
		
		Battle.EVENT_TYPE.MERCY_CHOICE_CHANGED:
			if(EVENT != mercy_slot):
				AudioManager.play_sound_with_pitch(button_choice_sound, 1);
			mercy_slot = EVENT;
			menu_renderer.set_selected(EVENT)
