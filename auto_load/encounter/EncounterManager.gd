extends Node

var current_id : int = -1;
var encounters = {
	
}

var battle_soul : BattleSoulRed = null;

func _init() -> void:
	encounter_set(-1, load("res://battle/enemy/BattleEnemy.tscn"), load("res://battle/enemy/test/battle_enemy_test.tscn")\
	, null, "* 请不要把巨石一次又一次的推上山顶。")

func encounter(id: int, _anim: bool = true):
	current_id = id;
	if(!encounters.has(id)): return;
	SceneManager._encounter_animation_start();

func encounter_get(id : int):
	if(!encounters.has(id)): return;
	return encounters[id];

func encounter_set(id: int, enemy0 : PackedScene, enemy1 : PackedScene = null, enemy2 : PackedScene = null, encounter_text: String = ""):
	encounters.set(id,{"enemy":[enemy0,enemy1,enemy2],"encounter_text": encounter_text});
	return;

func get_current_encounter_enemys():
	var _enemys = [];
	var _encounter = encounter_get(current_id);
	if(!_encounter):return;
	for i in _encounter.get("enemy",[]):
		if(i==null): continue;
		_enemys.append(i);
	return _enemys;

func get_current_encounter_text():
	var _encounter = encounter_get(current_id);
	if(!_encounter):return;
	return _encounter.encounter_text

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
