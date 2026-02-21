class_name EnemyManager extends Node

@export var battle: Battle

var enemies: Array[BattleEnemy] = []

func _ready() -> void:
	if not battle:
		battle = get_parent() as Battle
	
	if not SceneManager.is_battle():
		queue_free()
		return
	var encounter: Array = EncounterManager.get_current_encounter()
	if not encounter:
		return
	for packed_scene in encounter:
		var enemy: BattleEnemy = packed_scene.instantiate()
		add_child(enemy)
		enemy.battle = battle
		enemy.init()
		enemies.append(enemy)
	_arrange_enemies()

func _arrange_enemies() -> void:
	var count = enemies.size()
	if count == 0:
		return
	var center_x := 320.0
	var spacing := 200.0
	var start_x = center_x - (count - 1) * spacing / 2.0
	for i in range(count):
		if is_instance_valid(enemies[i]):
			enemies[i].position = Vector2(start_x + i * spacing, 120.0)

## 返回指定槽位的敌人，越界返回 null
func battle_get_enemy(slot: int) -> BattleEnemy:
	if slot < 0 or slot >= enemies.size():
		return null
	return enemies[slot]

func battle_get_enemies() -> Array[BattleEnemy]:
	return enemies

func battle_set_enemy(slot: int, packed: PackedScene) -> void:
	if slot < enemies.size():
		enemies[slot].queue_free()
	var enemy: BattleEnemy = packed.instantiate()
	add_child(enemy)
	enemy.battle = battle
	enemy.init()
	if slot < enemies.size():
		enemies[slot] = enemy
	else:
		enemies.append(enemy)

func battle_get_enemy_count() -> int:
	return enemies.size()

## 从战场移除一个敌人（退役后调用）
func remove_enemy(enemy: BattleEnemy) -> void:
	var idx = enemies.find(enemy)
	if idx >= 0:
		enemies.remove_at(idx)
		_arrange_enemies()
