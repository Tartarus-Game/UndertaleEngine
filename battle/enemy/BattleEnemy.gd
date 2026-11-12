class_name BattleEnemy extends Node2D

var battle : Battle;
@export var data: EnemyData
@export var wave_scene: PackedScene
@export var projectile_target := false
@export var projectile_hit_shape: Shape2D
@export var projectile_hit_offset := Vector2.ZERO

var choice_box_size : Vector2 = Vector2(100, 100);
var choice_box_offset : Vector2 = Vector2(0, 0);
var _checked : bool = false;
var _hp : float = 30;
var _hp_max : float = 30;
var _actions : Array[String] = [];
var _action_callbacks: Array[Callable] = []
var _name : String = "Dummy";
var spareable: bool = false

func _ready():
	position = Vector2(320, 120);

func init():
	if data == null:
		data = EnemyData.new()
	else:
		data = data.duplicate()
	_name = data.enemy_name
	_hp_max = data.max_hp
	_hp = _hp_max
	battle.BattleEvent.connect(on_battle_menu_changed);
	action_set(0, "检查");

func on_battle_menu_changed(_type, _state, _from):
	pass;

func set_checked(enable : bool):
	_checked = enable;
	return;

func get_is_checked():
	return _checked;

func get_hp():
	return _hp;

func get_hp_max():
	return _hp_max;

func set_enemy_name(__name : String):
	_name = __name;

func get_enemy_name():
	return _name;

func action_get_count():
	return _actions.size();

func get_actions() -> Array[String]:
	return _actions;

func action_set(slot : int, text : String, callback: Callable = Callable()):
	if slot < 0 or slot > action_get_count(): return;
	if slot == action_get_count():
		_actions.resize(_actions.size()+1)
		_action_callbacks.resize(_action_callbacks.size()+1)
	_actions.set(slot, text);
	_action_callbacks[slot] = callback
	
func action_get_name(slot : int):
	if slot < 0 or action_get_count() <= slot: return;
	return _actions[slot];

func take_damage(amount: float) -> float:
	var damage := maxf(0.0, amount - data.defense)
	_hp = maxf(0.0, _hp - damage)
	return damage

# Override this in an enemy scene to implement custom ACT options.
func perform_action(slot: int) -> String:
	if slot >= 0 and slot < _action_callbacks.size() and _action_callbacks[slot].is_valid():
		return str(_action_callbacks[slot].call())
	if slot == 0:
		_checked = true
		return "* %s - %d/%d HP, %d DEF.\n* %s" % [_name, int(_hp), int(_hp_max), int(data.defense), data.description]
	return "* Nothing happened."

func get_turn_dialog() -> String:
	return ""

func get_wave_scene(_turn: int) -> PackedScene:
	return wave_scene

func get_can_flee() -> bool:
	return data.can_flee


func get_flee_chance(turn: int) -> float:
	return clampf(data.flee_chance + data.flee_chance_per_turn * turn, 0.0, 1.0)

func get_attack() -> float:
	return data.attack
