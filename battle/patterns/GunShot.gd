class_name GunShot extends BattleBullet

signal fired

var fade_in := 0.25
var aim_duration := 0.5
var fire_duration := 0.1
var fade_out := 0.2
var radius := 8.0
var aim_distance := 35.0
var show_horizontal := true
var show_vertical := true
var prepare_sound: AudioStream
var fire_sound: AudioStream
var age := 0.0
var _activating := false
var _collision: CollisionShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	velocity = Vector2.ZERO
	destroy_on_contact = false
	lifetime = maxf(fade_in, 0.0) + maxf(aim_duration, 0.0) + maxf(fire_duration, 0.0) + maxf(fade_out, 0.0)
	var shape := CircleShape2D.new()
	shape.radius = radius
	_collision = CollisionShape2D.new()
	_collision.shape = shape
	add_child(_collision)
	super._ready()
	AudioManager.play_sound(prepare_sound)


func _physics_process(delta: float) -> void:
	var step := minf(delta, maxf(lifetime, 0.0))
	var previous := age
	age += step
	var fire_at := maxf(fade_in, 0.0) + maxf(aim_duration, 0.0)
	if previous <= fire_at and age > fire_at and fire_duration > 0.0:
		AudioManager.play_sound(fire_sound)
		fired.emit()
		_activating = true
		_check_activation()
		_activating = false
	queue_redraw()
	super._physics_process(delta)


func _check_activation() -> void:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _collision.shape
	query.transform = _collision.global_transform
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		if hit.collider is Area2D: _try_contact(hit.collider)


func is_graze_active() -> bool:
	var fire_at := maxf(fade_in, 0.0) + maxf(aim_duration, 0.0)
	return age >= fire_at and age < fire_at + maxf(fire_duration, 0.0)


func _try_contact(area: Area2D, delta: float = 0.0) -> void:
	if not _activating and not is_graze_active(): return
	super._try_contact(area, delta)


func _draw() -> void:
	var colors := [Color.WHITE, Color.CYAN, Color.ORANGE, Color.LIME_GREEN]
	var color: Color = colors[rule]
	var fade := clampf(age / fade_in, 0.0, 1.0) if fade_in > 0.0 else 1.0
	var fire_at := maxf(fade_in, 0.0) + maxf(aim_duration, 0.0)
	var after_fire := age - fire_at - maxf(fire_duration, 0.0)
	if after_fire > 0.0:
		fade *= 1.0 - clampf(after_fire / fade_out, 0.0, 1.0) if fade_out > 0.0 else 0.0
	color.a = fade
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, 2.0)
	if age < fire_at:
		var progress := clampf((age - fade_in) / aim_duration, 0.0, 1.0) if aim_duration > 0.0 else 1.0
		var offset := aim_distance * (1.0 - progress)
		if show_horizontal:
			draw_line(Vector2(-offset - 6, 0), Vector2(-offset, 0), color, 2.0)
			draw_line(Vector2(offset, 0), Vector2(offset + 6, 0), color, 2.0)
		if show_vertical:
			draw_line(Vector2(0, -offset - 6), Vector2(0, -offset), color, 2.0)
			draw_line(Vector2(0, offset), Vector2(0, offset + 6), color, 2.0)
	elif is_graze_active():
		draw_circle(Vector2.ZERO, radius, color)
