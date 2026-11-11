extends Node

var current_id : int = -1;
var encounters = {
	-1: [load("res://battle/enemy/BattleEnemy.tscn"), load("res://battle/enemy/test/battle_enemy_test.tscn")]
}

var battle_soul : BattleSoulRed = null;
var return_scene_path: String = ""
var last_result: String = ""

signal battle_finished(result: String)

func encounter(id: int, _anim: bool = true):
	if(!encounters.has(id)): return;
	current_id = id;
	var scene = get_tree().current_scene
	return_scene_path = scene.scene_file_path if scene else ""
	last_result = ""
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
	return battle_soul;

func finish_battle(result: String) -> void:
	last_result = result
	battle_soul = null
	battle_finished.emit(result)
	if not return_scene_path.is_empty():
		SceneManager.goto_scene_to_path(return_scene_path)
