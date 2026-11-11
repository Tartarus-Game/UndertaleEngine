class_name EnemyDamageDisplay extends Node2D

const DURATION := 1.0
@onready var font: Font = load("res://font/Mars Needs Cunnilingus.ttf")

var damage := 0
var hp_before := 0.0
var hp_after := 0.0
var hp_max := 1.0
var bar_width := 100.0
var elapsed := 0.0


func setup(amount: int, before: float, after: float, maximum: float, width: float) -> void:
	damage = amount
	hp_before = before
	hp_after = after
	hp_max = maxf(maximum, 1.0)
	bar_width = maxf(width, 40.0)


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= DURATION:
		queue_free()


func _draw() -> void:
	var text := "MISS" if damage <= 0 else str(damage)
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var rise := minf(elapsed, 0.4) * 40.0
	draw_string(font, Vector2(-text_width / 2.0, -30.0 - rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
	if damage > 0:
		var bar := Rect2(-bar_width / 2.0, 20.0, bar_width, 10.0)
		draw_rect(bar, Color(0.35, 0.0, 0.0))
		var progress := clampf((elapsed - 0.2) / 0.4, 0.0, 1.0)
		var current := lerpf(hp_before, hp_after, progress) / hp_max
		draw_rect(Rect2(bar.position, Vector2(bar_width * clampf(current, 0.0, 1.0), bar.size.y)), Color.YELLOW)
		draw_rect(bar, Color.WHITE, false, 1.0)
