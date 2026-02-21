class_name EnemyManager extends Node;
@export var battle : Battle;
var enemys:Array[BattleEnemy] = [];

#加载敌人
func battle_load_enemy(_enemys):
	if(!_enemys): return;
	for i in _enemys:
		var enemy = i.instantiate() as BattleEnemy;
		enemy.battle = battle;
		enemy.enemy_slot = len(enemys)
		enemy.init();
		add_child(enemy);
		enemys.append(enemy);

## 按槽位读取敌人实例。
func battle_get_enemy(slot : int) -> BattleEnemy:
	if(slot>=len(enemys) and slot < 0):return;
	return enemys[slot];

 ##获取当前所有敌人。
func battle_get_enemys() -> Array[BattleEnemy]:
	return enemys;
## 替换指定槽位敌人（调试/特殊事件使用）。
func battle_set_enemy(slot : int, packed : PackedScene):
	
	if(len(enemys)>=slot):
		enemys[slot].queue_free();
	var enemy = packed.instantiate() as BattleEnemy;
	enemy.battle = self;
	enemy.init();
	add_child(enemy);
	enemys[slot] = enemy;

## 当前敌人数量。
func battle_get_enemy_count() -> int:
	return len(enemys);

## 安全移除敌人（释放节点并从数组删掉）。
func battle_remove_enemy(slot: int):
	if(slot < 0 or slot >= len(enemys)): return;
	enemys[slot].queue_free();
	enemys.remove_at(slot);

## 战场是否还有敌人。
func battle_has_enemies() -> bool:
	return len(enemys) > 0;
