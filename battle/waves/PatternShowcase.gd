class_name PatternShowcase extends BattleWave

func advance_wave(previous: float, now: float) -> void:
	var center: Vector2 = battle.battle_box.global_position
	if previous <= 0.0 and now > 0.0:
		battle.soul.set_mode("blue")
		BattlePatterns.platform(battle, center + Vector2(0, 25), 75, Vector2(30, 0), duration)
	if previous < 0.5 and now >= 0.5:
		BattlePatterns.wall(battle, center + Vector2(120, 32), 4, Vector2(35, 0), 50, Vector2(-90, 0))
	if previous < 2.0 and now >= 2.0:
		BattlePatterns.blaster(battle, center + Vector2(-120, -40), center, 0.8, 0.7)
	if previous < 3.5 and now >= 3.5:
		BattlePatterns.ring(battle, center, 8, 50, 25, 1.2, 2.0)
	if previous < 5.0 and now >= 5.0:
		BattlePatterns.pulse(battle, center, 100, 1.0)
