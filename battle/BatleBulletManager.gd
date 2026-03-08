class_name BattleBulletManager extends Node

func spawn_bullet(node: BattleBullet):
	add_child(node)
	return node
