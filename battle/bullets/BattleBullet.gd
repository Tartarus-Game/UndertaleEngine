class_name BattleBullet extends Area2D

# Speeds are pixels/second; lifetime is seconds. Extend this scene for patterns.
@export var velocity := Vector2(-115.0, 0.0)
@export var damage := 3
@export var lifetime := 6.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color.WHITE)


func _on_area_entered(area: Area2D) -> void:
	var soul := area.get_parent()
	if soul is BattleSoulRed and soul.take_damage(damage):
		queue_free()
