class_name PatternShowcase extends BattleWave

func advance_wave(previous: float, now: float) -> void:
	var center: Vector2 = battle.battle_box.global_position
	if previous <= 0.0 and now > 0.0:
		battle.soul.set_mode("blue")
		battle.graze_enabled = true
		var platform := BattlePatterns.platform(battle, center + Vector2(0, 25), 75, Vector2(30, 0), duration)
		platform.bounce_in_arena = true
	if previous < 0.5 and now >= 0.5:
		BattlePatterns.wall(battle, center + Vector2(120, 32), 4, Vector2(35, 0), 50, Vector2(-90, 0))
	if previous < 1.25 and now >= 1.25:
		BattlePatterns.targeted_pellet(battle, center + Vector2(200, -45), center + Vector2(70, -45), Vector2(-180, 0), 0.5, 0.4)
	if previous < 2.0 and now >= 2.0:
		BattlePatterns.blaster(battle, center + Vector2(-120, -40), center, 0.8, 0.7)
	if previous < 2.75 and now >= 2.75:
		BattlePatterns.bone_cone(battle, center + Vector2(170, 0), PI / 2.0, PI, 0.5, 240.0, BattleBullet.Rule.BLUE, {"speed": 60.0})
	if previous < 3.5 and now >= 3.5:
		BattlePatterns.ring(battle, center, 8, 50, 25, 1.2, 2.0)
	if previous < 4.0 and now >= 4.0:
		BattlePatterns.gun(battle, center + Vector2(-40, -10), 0.2, 0.6, 0.1)
	if previous < 5.0 and now >= 5.0:
		BattlePatterns.pulse(battle, center, 100, 1.0)
