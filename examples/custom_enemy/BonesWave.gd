extends BattleWave

var next_spawn := 0.2
var spawn_index := 0
var interval := 0.45


func advance_wave(_previous: float, now: float) -> void:
	# A loop preserves every scheduled spawn even when a long update crosses
	# more than one interval. All times are seconds and speeds are pixels/s.
	while next_spawn <= now and next_spawn < duration:
		var side := 1.0 if spawn_index % 2 == 0 else -1.0
		var lane := -35.0 if spawn_index % 2 == 0 else 35.0
		var center: Vector2 = battle.battle_box.position
		var bone := BattlePatterns.bone(battle, center + Vector2(side * 130.0, lane), 35.0, Vector2(-side * 110.0, 0))
		if is_instance_valid(source_enemy):
			bone.damage = roundi(source_enemy.get_attack())
		spawn_index += 1
		next_spawn += interval
