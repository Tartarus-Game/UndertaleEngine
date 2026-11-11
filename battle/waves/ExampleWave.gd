class_name ExampleWave extends BattleWave

var interval: float = 0.55
var next_spawn_time: float = 0.0
var bullet_count: int = 0


func advance_wave(_previous: float, now: float) -> void:
	while next_spawn_time < duration and next_spawn_time <= now:
		var bullet: BattleBullet = Battle.BULLET_SCENE.instantiate()
		var from_right := bullet_count % 2 == 0
		var lane := (bullet_count * 37) % 101 - 50
		bullet.velocity = Vector2(-115 if from_right else 115, 0)
		battle.spawn_bullet(bullet, battle.battle_box.position + Vector2(130 if from_right else -130, lane))
		bullet_count += 1
		next_spawn_time += interval
