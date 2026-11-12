class_name SoulProjectile extends Node2D

var velocity := Vector2.UP * 360.0
var lifetime := 2.0
var damage := 1.0
var battle: Battle


func _physics_process(delta: float) -> void:
	if lifetime <= 0.0:
		queue_free()
		return
	var previous := global_position
	var motion := velocity * minf(delta, maxf(lifetime, 0.0))
	lifetime -= delta
	var first_fraction := INF
	var first_bullet: BattleBullet
	var first_enemy: BattleEnemy
	for bullet in get_tree().get_nodes_in_group("shootable_bullets"):
		if not bullet is BattleBullet or bullet.is_queued_for_deletion(): continue
		var fraction := _contact_fraction(previous, motion, bullet.global_position, 8.0)
		if fraction < first_fraction:
			first_fraction = fraction
			first_bullet = bullet
	if is_instance_valid(battle):
		for enemy in battle.battle_get_enemys():
			if not enemy.projectile_target or enemy.is_queued_for_deletion(): continue
			var fraction := _contact_fraction(previous, motion, enemy.global_position, 15.0)
			if fraction < first_fraction:
				first_fraction = fraction
				first_enemy = enemy
				first_bullet = null
	if first_fraction < INF:
		global_position = previous + motion * first_fraction
		if first_bullet: first_bullet.hit_by_soul_shot(damage)
		else: battle.damage_enemy_from_projectile(first_enemy, damage)
		queue_free()
		return
	global_position = previous + motion
	if lifetime <= 0.0: queue_free()


func _contact_fraction(start: Vector2, motion: Vector2, center: Vector2, radius: float) -> float:
	var offset := start - center
	var c := offset.length_squared() - radius * radius
	if c <= 0.0: return 0.0
	var a := motion.length_squared()
	if is_zero_approx(a): return INF
	var b := offset.dot(motion)
	var discriminant := b * b - a * c
	if discriminant < 0.0: return INF
	var fraction := (-b - sqrt(discriminant)) / a
	return fraction if fraction >= 0.0 and fraction <= 1.0 else INF


func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color.YELLOW)
