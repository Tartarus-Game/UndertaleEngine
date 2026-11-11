class_name FightMeter extends Node2D

signal missed

@export var duration: float = 1.5 # seconds for the marker to cross the bar
@onready var target: Texture2D = load("res://battle/UI/spr_target_0.png")
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
	var size := target.get_size()
	draw_texture(target, -size / 2.0)
	var x := lerpf(-size.x / 2.0, size.x / 2.0, clampf(elapsed / duration, 0.0, 1.0))
	draw_rect(Rect2(x - 6, -size.y / 2.0 - 4, 12, size.y + 8), Color.BLACK)
	draw_rect(Rect2(x - 3, -size.y / 2.0 - 1, 6, size.y + 2), Color.WHITE)
