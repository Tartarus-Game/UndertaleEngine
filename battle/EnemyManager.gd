class_name EnemyManager extends Node;
@export var battle : Battle;
var enemys : Array[BattleEnemy] = [];
func _ready() -> void:
	var _enemys = EncounterManager.get_current_encounter();
	if(!_enemys): return;
	for i in _enemys:
		var enemy = i.instantiate();
		enemy.battle = battle;
		enemy.init();
		add_child(enemy);
		enemys.append(enemy);

func battle_get_enemy(slot : int):
	if slot >= len(enemys) or slot < 0: return null;
	return enemys[slot];

func battle_get_enemys() -> Array[BattleEnemy]:
	return enemys;

func battle_set_enemy(slot : int, packed : PackedScene):
	if slot < 0 or slot >= 3 or slot > enemys.size(): return;
	var enemy = packed.instantiate();
	enemy.battle = battle;
	enemy.init();
	add_child(enemy);
	if slot == enemys.size():
		enemys.append(enemy)
	else:
		enemys[slot].queue_free()
		enemys[slot] = enemy;

func battle_remove_enemy(enemy: BattleEnemy) -> void:
	if enemys.has(enemy):
		enemys.erase(enemy)
		enemy.queue_free()

func battle_get_enemy_count():
	return len(enemys);
