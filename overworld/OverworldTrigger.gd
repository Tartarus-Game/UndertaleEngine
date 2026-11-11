class_name OverworldTrigger extends Area2D

signal triggered(actor: OverworldChar)


func interact(actor: OverworldChar) -> void:
	triggered.emit(actor)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 9.0, Color(0.95, 0.8, 0.2))
	draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
