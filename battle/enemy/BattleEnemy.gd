class_name BattleEnemy extends Node2D

var battle : Battle;

var choice_box_size : Vector2 = Vector2(100, 100);
var choice_box_offset : Vector2 = Vector2(0, 0);
var _checked : bool = false;
var _spareable : bool = false;
var _can_flee : bool = true;
var _hp : float = 0;
var _hp_max : float = 0;
var _actions = [];
var _name : String = "null";

func _ready():
	position = Vector2(320, 120);

func init():
	battle.BattleEvent.connect(on_battle_menu_changed);
	action_set(0, "检查", "[b]检查敌人的属性，获得准确的数值。");

func on_battle_menu_changed(_type, _state, _from):
	pass;

func set_checked(enable : bool):
	_checked = enable;
	return;

func get_is_checked():
	return _checked;

func set_spareable(enable: bool):
	_spareable = enable;

func get_spareable() -> bool:
	return _spareable;

func get_can_flee() -> bool:
	return _can_flee;

func get_hp():
	return _hp;

func get_hp_max():
	return _hp_max;

func set_hp(val: float):
	_hp = clampf(val, 0, _hp_max)

func set_enemy_name(__name : String):
	_name = __name;

func get_enemy_name():
	return _name;

func action_get_count():
	return _actions.size();

func get_actions():
	return _actions;

func action_set(slot : int, text : String, desc : String):
	if(action_get_count() < slot): return;
	_actions.resize(_actions.size()+1);
	_actions.set(slot, [text, desc]);
	
func action_get_name(slot : int):
	if(action_get_count() <= slot): return;
	return _actions[slot][0];
	
func action_get_desc(slot : int):
	if(action_get_count() <= slot): return;
	return _actions[slot][1];
