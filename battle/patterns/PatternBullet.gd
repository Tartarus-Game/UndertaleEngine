class_name PatternBullet extends BattleBullet

enum Shape { BONE, BEAM, PULSE, PELLET }
var shape_type := Shape.BONE
var length := 50.0
var width := 8.0
var warning := 0.0
var age := 0.0
var angular_velocity := 0.0
var expansion_speed := 90.0
var radius := 2.0
var circle: CircleShape2D
var launch_velocity := Vector2.ZERO


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	var collision := CollisionShape2D.new()
	if shape_type == Shape.PULSE or shape_type == Shape.PELLET:
		circle = CircleShape2D.new()
		circle.radius = radius + width if shape_type == Shape.PULSE else width
		collision.shape = circle
	else:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(width, length) if shape_type == Shape.BONE else Vector2(length, width)
		collision.shape = rect
	add_child(collision)
	super._ready()


func _physics_process(delta: float) -> void:
	var previous_age := age
	age += delta
	rotation += angular_velocity * delta
	if shape_type == Shape.PULSE:
		radius += expansion_speed * delta
		circle.radius = radius + width
	elif shape_type == Shape.PELLET and age >= warning:
		velocity = launch_velocity
		# Only integrate the part of this update after the warning expires.
		position -= velocity * clampf(warning - previous_age, 0.0, delta)
	queue_redraw()
	super._physics_process(delta)


func _try_contact(area: Area2D, delta: float = 0.0) -> void:
	if age < warning: return
	if shape_type == Shape.PULSE and absf(area.global_position.distance_to(global_position) - radius) > width + 4.0: return
	super._try_contact(area, delta)


func _draw() -> void:
	var colors := [Color.WHITE, Color.CYAN, Color.ORANGE, Color.LIME_GREEN]
	var color: Color = colors[rule]
	if shape_type == Shape.PELLET:
		draw_circle(Vector2.ZERO, width, color if age >= warning else Color(1.0, 0.7, 0.2, 0.7))
	elif age < warning:
		draw_line(Vector2(-length/2, 0), Vector2(length/2, 0), Color(1, 0.2, 0.2, 0.7), 2.0)
	elif shape_type == Shape.PULSE:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, color, width)
	elif shape_type == Shape.BONE:
		draw_rect(Rect2(-width/2, -length/2, width, length), color)
		for y in [-length/2, length/2]:
			draw_circle(Vector2(-width*0.35, y), width*0.55, color)
			draw_circle(Vector2(width*0.35, y), width*0.55, color)
	else:
		draw_rect(Rect2(-length/2, -width/2, length, width), color)
