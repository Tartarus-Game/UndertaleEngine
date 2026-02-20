extends Node

var current_id : int = -1;
var encounters = {
	-1: [load("res://battle/enemy/BattleEnemy.tscn"), load("res://battle/enemy/test/battle_enemy_test.tscn")]
}

var battle_soul : BattleSoulRed = null;

func encounter(id: int, _anim: bool = true):
	current_id = id;
	if(!encounters.has(id)): return;
	SceneManager._encounter_animation_start();

func encounter_get(id : int):
	if(!encounters.has(id)): return;
	return encounters[id];

func encounter_set(id: int, enemy0 : PackedScene, enemy1 : PackedScene = null, enemy2 : PackedScene = null):
	encounters.set(id,[enemy0,enemy1,enemy2]);
	return;

func get_current_encounter():
	var _enemys = [];
	var enemys = encounter_get(current_id);
	if(!enemys):return;
	for i in enemys:
		if(i==null): continue;
		_enemys.append(i);
	return _enemys;

func get_soul():
	pass;
