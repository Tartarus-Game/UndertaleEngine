class_name SoulProjectile extends Node2D

var velocity := Vector2.UP * 360.0
var lifetime := 2.0
var damage := 1.0
var battle: Battle


func _physics_process(delta: float) -> void:
	var previous := global_position
	global_position += velocity * delta
	lifetime -= delta
	for bullet in get_tree().get_nodes_in_group("shootable_bullets"):
		var point: Vector2 = Geometry2D.get_closest_point_to_segment(bullet.global_position, previous, global_position)
		if point.distance_to(bullet.global_position) <= 8.0:
			bullet.hit_by_soul_shot(damage)
			queue_free()
			return
	if battle:
		for enemy in battle.battle_get_enemys():
			var point: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, previous, global_position)
			if point.distance_to(enemy.global_position) <= 15.0 and enemy.projectile_target:
				battle.damage_enemy_from_projectile(enemy, damage)
				queue_free()
				return
	if lifetime <= 0.0: queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color.YELLOW)
