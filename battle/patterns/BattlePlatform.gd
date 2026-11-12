class_name BattlePlatform extends AnimatableBody2D

var velocity := Vector2.ZERO # pixels per second
var platform_width := 60.0
var lifetime := 6.0
var bounce_in_arena := false
var arena := Rect2()
var arena_source: BattleSoul


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
	var step := minf(delta, maxf(lifetime, 0.0))
	var bounds := arena_source.arena if is_instance_valid(arena_source) else arena
	if bounce_in_arena and bounds.size != Vector2.ZERO:
		# Use the platform's rotated dimensions, not just its center.
		var half := Vector2(platform_width / 2.0, 3.0)
		var angle := global_rotation
		var extents := Vector2(
			absf(cos(angle)) * half.x + absf(sin(angle)) * half.y,
			absf(sin(angle)) * half.x + absf(cos(angle)) * half.y
		)
		var x := _reflect_axis(global_position.x, velocity.x, bounds.position.x + extents.x, bounds.end.x - extents.x, step)
		var y := _reflect_axis(global_position.y, velocity.y, bounds.position.y + extents.y, bounds.end.y - extents.y, step)
		global_position = Vector2(x.x, y.x)
		velocity = Vector2(x.y, y.y)
	else:
		global_position += velocity * step
	lifetime -= delta
	if lifetime <= 0.0: queue_free()


func _reflect_axis(value: float, speed: float, low: float, high: float, delta: float) -> Vector2:
	if high <= low:
		return Vector2((low + high) / 2.0, 0.0)
	var width := high - low
	var phase := fposmod(value - low + speed * delta, 2.0 * width)
	if is_zero_approx(phase):
		return Vector2(low, absf(speed))
	if is_equal_approx(phase, width):
		return Vector2(high, -absf(speed))
	if phase < width:
		return Vector2(low + phase, speed)
	return Vector2(high - (phase - width), -speed)


func _draw() -> void:
	draw_rect(Rect2(-platform_width/2, -3, platform_width, 6), Color.WHITE)
