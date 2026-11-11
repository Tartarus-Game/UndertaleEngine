class_name FightMeter extends Node2D

signal missed

@export var duration: float = 1.5 # seconds for the marker to cross the bar
var elapsed := 0.0
var running := false


func start() -> void:
	elapsed = 0.0
	running = true
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not running:
		return
	elapsed = minf(duration, elapsed + delta)
	queue_redraw()
	if elapsed >= duration:
		running = false
		missed.emit()


func accuracy() -> float:
	return 1.0 - absf(clampf(elapsed / duration, 0.0, 1.0) * 2.0 - 1.0)


func _draw() -> void:
	draw_rect(Rect2(-220, -12, 440, 24), Color(0.6, 0.2, 0.2))
	draw_rect(Rect2(-25, -12, 50, 24), Color(0.95, 0.85, 0.2))
	var x := lerpf(-220.0, 220.0, clampf(elapsed / duration, 0.0, 1.0))
	draw_rect(Rect2(x - 3, -20, 6, 40), Color.WHITE)
