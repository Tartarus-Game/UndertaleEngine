class_name EnemyManager extends Node;
@export var battle : Battle;
var enemys = [];
func _ready() -> void:
	if(!SceneManager.is_battle()):queue_free();
	var _enemys = EncounterManager.get_current_encounter();
	if(!_enemys): return;
	for i in _enemys:
		var enemy = i.instantiate();
		enemy.battle = battle;
		enemy.init();
		add_child(enemy);
		enemys.append(enemy);

func battle_get_enemy(slot : int):
	if(slot>=len(enemys) and slot < 0):return;
	return enemys[slot];

func battle_get_enemys():
	return enemys;

func battle_set_enemy(slot : int, packed : PackedScene):
	if(len(enemys)>=slot):
		enemys[slot].queue_free();
	var enemy = packed.instantiate();
	enemy.battle = self;
	enemy.init();
	add_child(enemy);
	enemys[slot] = enemy;

func battle_get_enemy_count():
	return len(enemys);

func battle_remove_enemy(slot: int):
	if(slot < 0 or slot >= len(enemys)): return;
	enemys[slot].queue_free();
	enemys.remove_at(slot);

func battle_has_enemies() -> bool:
	return len(enemys) > 0;
