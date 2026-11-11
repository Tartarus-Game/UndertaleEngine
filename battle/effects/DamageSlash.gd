class_name DamageSlash extends Node2D

var duration := 0.2
var elapsed := 0.0


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= duration: queue_free()


func _draw() -> void:
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var alpha := 1.0 - progress
	draw_line(Vector2(-35, -55), Vector2(35, 55), Color(1, 0.15, 0.15, alpha), 9.0 * (1.0 - progress * 0.5), true)
	draw_line(Vector2(-35, -55), Vector2(35, 55), Color(1, 1, 1, alpha), 3.0, true)
