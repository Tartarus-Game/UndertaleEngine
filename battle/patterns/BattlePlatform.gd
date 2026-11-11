class_name BattlePlatform extends AnimatableBody2D

var velocity := Vector2.ZERO # pixels per second
var platform_width := 60.0
var lifetime := 6.0
var bounce_in_arena := false
var arena := Rect2()


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var rect := RectangleShape2D.new()
	rect.size = Vector2(platform_width, 6.0)
	var hitbox := CollisionShape2D.new()
	hitbox.shape = rect
	hitbox.one_way_collision = true
	add_child(hitbox)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if bounce_in_arena and arena.size != Vector2.ZERO:
		if global_position.x < arena.position.x or global_position.x > arena.end.x: velocity.x = -velocity.x
		if global_position.y < arena.position.y or global_position.y > arena.end.y: velocity.y = -velocity.y
	if lifetime <= 0.0: queue_free()


func _draw() -> void:
	draw_rect(Rect2(-platform_width/2, -3, platform_width, 6), Color.WHITE)
