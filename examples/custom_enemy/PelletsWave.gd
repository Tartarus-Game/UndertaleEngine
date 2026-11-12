extends BattleWave

var next_spawn := 0.2
var spawn_index := 0
var interval := 0.45


func advance_wave(_previous: float, now: float) -> void:
	while next_spawn <= now and next_spawn < duration:
		var center: Vector2 = battle.battle_box.position
		var lane := -40.0 if spawn_index % 2 == 0 else 40.0
		var pellet := BattlePatterns.pellet(battle, center + Vector2(125.0, lane), center, 0.25, 140.0)
		if is_instance_valid(source_enemy):
			pellet.damage = roundi(source_enemy.get_attack())
		spawn_index += 1
		next_spawn += interval
