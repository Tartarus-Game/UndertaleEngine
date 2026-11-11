class_name BlasterHead extends Node2D

var charge := 0.8
var duration := 0.8
var age := 0.0


func _physics_process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age >= charge + duration: queue_free()


func _draw() -> void:
	var color := Color.WHITE if age >= charge else Color(0.7, 0.7, 0.7)
	draw_circle(Vector2.ZERO, 19.0, color)
	draw_circle(Vector2(3, -7), 4.0, Color.BLACK)
	draw_circle(Vector2(3, 7), 4.0, Color.BLACK)
	draw_rect(Rect2(8, -10, 12, 20), Color.BLACK)
	if age >= charge: draw_line(Vector2(12, -10), Vector2(12, 10), Color.WHITE, 3.0)
