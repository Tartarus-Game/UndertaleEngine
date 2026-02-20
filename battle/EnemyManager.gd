class_name EnemyManager extends Node;
@export var battle : Battle;
var enemys = [];
func _ready() -> void:
	# 进入战斗场景时根据 EncounterManager 实例化敌人列表。
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
	# 按槽位读取敌人实例。
	if(slot>=len(enemys) and slot < 0):return;
	return enemys[slot];

func battle_get_enemys():
	# 获取当前所有敌人。
	return enemys;

func battle_set_enemy(slot : int, packed : PackedScene):
	# 替换指定槽位敌人（调试/特殊事件使用）。
	if(len(enemys)>=slot):
		enemys[slot].queue_free();
	var enemy = packed.instantiate();
	enemy.battle = self;
	enemy.init();
	add_child(enemy);
	enemys[slot] = enemy;

func battle_get_enemy_count():
	# 当前敌人数量。
	return len(enemys);

func battle_remove_enemy(slot: int):
	# 安全移除敌人（释放节点并从数组删掉）。
	if(slot < 0 or slot >= len(enemys)): return;
	enemys[slot].queue_free();
	enemys.remove_at(slot);

func battle_has_enemies() -> bool:
	# 战场是否还有敌人。
	return len(enemys) > 0;
