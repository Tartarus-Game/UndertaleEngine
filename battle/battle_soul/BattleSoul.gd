class_name BattleSoul extends CharacterBody2D

signal hurt(damage: int)
signal defeated
signal shot_requested(origin: Vector2, direction: Vector2)
signal grazed(bullet: BattleBullet)

@export var speed := 180.0
@export var invulnerability_time := 1.0
@export var gravity_acceleration := 1100.0
@export var maximum_fall_speed := 400.0
@export var jump_speed := 350.0
@export_range(0.0, 1.0, 0.05) var jump_release_speed_ratio := 0.35
@export var karma_per_second := 6.0
@export var graze_enabled := false:
	set(value):
		graze_enabled = value
		if is_instance_valid(_graze_area): _graze_area.set_deferred("monitoring", value)
@export_range(4.0, 100.0, 1.0) var graze_radius := 20.0:
	set(value):
		graze_radius = value
		if is_instance_valid(_graze_shape): _graze_shape.radius = value
@export_range(0.01, 5.0, 0.01) var graze_interval := 1.0 / 6.0
@onready var sprite: AnimatedSprite2D = $sprite

var movement_enabled := false
var arena := Rect2()
var arena_polygon := PackedVector2Array()
var invulnerability_remaining := 0.0
var mode := "red"
var gravity_direction := Vector2.DOWN
var gravity_speed := 0.0
var is_moving := false
var shield_direction := Vector2.UP
var last_direction := Vector2.UP
var karma_timer := 0.0
var _jump_active := false
var _graze_area: Area2D
var _graze_shape: CircleShape2D
var _graze_cooldown := 0.0
var _sweep_frame := -1
var _sweep_start := Vector2.ZERO
var _sweep_end := Vector2.ZERO
var _hurt_polygon_cache := {}


func _ready() -> void:
	# Record the soul's actual movement before bullets evaluate their sweeps.
	if process_physics_priority == 0: process_physics_priority = -50
	add_to_group("battle_souls")
	_graze_area = Area2D.new()
	_graze_area.name = "GrazeArea"
	_graze_area.collision_layer = 0
	_graze_area.collision_mask = 16
	_graze_area.monitorable = false
	_graze_area.monitoring = graze_enabled
	_graze_shape = CircleShape2D.new()
	_graze_shape.radius = graze_radius
	var collision := CollisionShape2D.new()
	collision.shape = _graze_shape
	_graze_area.add_child(collision)
	add_child(_graze_area)


func set_mode(value: String) -> void:
	mode = value.to_lower()
	gravity_speed = 0.0
	_jump_active = false
	velocity = Vector2.ZERO
	var color := Color.RED
	if has_mode("blue"): color = Color(0.25, 0.35, 1.0)
	elif has_mode("green"): color = Color.GREEN
	elif has_mode("yellow"): color = Color.YELLOW
	elif has_mode("aqua"): color = Color.CYAN
	elif has_mode("orange"): color = Color.ORANGE
	if is_instance_valid(sprite):
		var material := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; uniform vec4 tint : source_color; void fragment() { vec4 p = texture(TEXTURE, UV); COLOR = vec4(tint.rgb * max(p.r,max(p.g,p.b)), p.a) * COLOR; }"
		material.shader = shader
		material.set_shader_parameter("tint", color)
		sprite.material = material
	queue_redraw()


func has_mode(name: String) -> bool:
	return name in mode.split("+")


func _physics_process(delta: float) -> void:
	_sweep_frame = Engine.get_physics_frames()
	_sweep_start = global_position
	_sweep_end = _sweep_start
	advance_invulnerability(delta)
	advance_karma(delta)
	_graze_cooldown = maxf(0.0, _graze_cooldown - delta)
	if not movement_enabled:
		velocity = Vector2.ZERO
		is_moving = false
		return
	var before := global_position
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		last_direction = direction.normalized()
		if has_mode("green"):
			shield_direction = _cardinal(direction)
			queue_redraw()
	if has_mode("aqua"):
		direction = -direction
	if has_mode("orange"):
		if direction != Vector2.ZERO:
			last_direction = direction.normalized()
		direction = last_direction
	if has_mode("green") and mode == "green":
		direction = Vector2.ZERO
	var current_speed := speed * (0.5 if Input.is_action_pressed("ui_cancel") else 1.0)
	if has_mode("blue"):
		var gravity := _cardinal(gravity_direction)
		up_direction = -gravity
		var tangent := Vector2(gravity.y, -gravity.x)
		var grounded := is_on_floor() or _at_arena_floor(gravity)
		if grounded and gravity_speed > 0.0:
			gravity_speed = 0.0
			_jump_active = false
		if grounded and _jump_pressed(gravity):
			gravity_speed = -jump_speed
			_jump_active = true
		elif _jump_active and gravity_speed < 0.0 and not Input.is_action_pressed(_jump_action(gravity)):
			gravity_speed = maxf(gravity_speed, -jump_speed * jump_release_speed_ratio)
			_jump_active = false
		gravity_speed = minf(gravity_speed + gravity_acceleration * delta, maximum_fall_speed)
		velocity = tangent * direction.dot(tangent) * current_speed + gravity * gravity_speed
	else:
		velocity = direction * current_speed
	move_and_slide()
	clamp_to_arena()
	if has_mode("blue") and gravity_speed < 0.0:
		var gravity := _cardinal(gravity_direction)
		if is_on_ceiling() or (arena_polygon.is_empty() and _at_arena_floor(-gravity)):
			gravity_speed = 0.0
			_jump_active = false
	is_moving = global_position.distance_squared_to(before) > 0.000001
	_sweep_end = global_position
	_check_graze()
	if has_mode("yellow") and Input.is_action_just_pressed("ui_accept"):
		shot_requested.emit(global_position, last_direction)


func sweep_motion() -> Vector2:
	return _sweep_end - _sweep_start if _sweep_frame == Engine.get_physics_frames() else Vector2.ZERO


func sweep_hurt_shapes() -> Array[Dictionary]:
	var shapes: Array[Dictionary] = []
	var hurtbox := get_node_or_null("HurtBox") as Area2D
	if not hurtbox or not hurtbox.monitorable: return shapes
	for child in hurtbox.get_children():
		if child is CollisionShape2D and not child.disabled and child.shape:
			shapes.append({"shape": child.shape, "transform": child.global_transform})
		elif child is CollisionPolygon2D and not child.disabled and child.build_mode == CollisionPolygon2D.BUILD_SOLIDS:
			var id := child.get_instance_id()
			if not _hurt_polygon_cache.has(id) or _hurt_polygon_cache[id].polygon != child.polygon:
				var parts: Array[ConvexPolygonShape2D] = []
				for points in Geometry2D.decompose_polygon_in_convex(child.polygon):
					var part := ConvexPolygonShape2D.new()
					part.points = points
					parts.append(part)
				_hurt_polygon_cache[id] = {"polygon": child.polygon, "parts": parts}
			for part in _hurt_polygon_cache[id].parts:
				shapes.append({"shape": part, "transform": child.global_transform})
	return shapes


func _check_graze() -> void:
	if not graze_enabled or invulnerability_remaining > 0.0 or _graze_cooldown > 0.000001:
		return
	for area in _graze_area.get_overlapping_areas():
		var bullet := area as BattleBullet
		if not bullet or bullet.is_queued_for_deletion() or not bullet.grazeable or not bullet.is_graze_active() or bullet.rule == BattleBullet.Rule.HEAL:
			continue
		if bullet is PatternBullet:
			if bullet.age < bullet.warning: continue
			if bullet.shape_type == PatternBullet.Shape.PULSE and absf(bullet.global_position.distance_to(global_position) - bullet.radius) > bullet.width + graze_radius:
				continue
		if _bullet_touches_hurtbox(bullet): continue
		_graze_cooldown = graze_interval
		grazed.emit(bullet)
		return


func _bullet_touches_hurtbox(bullet: BattleBullet) -> bool:
	if bullet is PatternBullet and bullet.shape_type == PatternBullet.Shape.PULSE:
		return absf(bullet.global_position.distance_to(global_position) - bullet.radius) <= bullet.width + 4.0
	var hurtbox := $HurtBox as Area2D
	for child in bullet.get_children():
		if not child is CollisionShape2D or child.disabled or child.shape == null: continue
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = child.shape
		query.transform = child.global_transform
		query.collision_mask = hurtbox.collision_layer
		query.collide_with_areas = true
		query.collide_with_bodies = false
		for hit in get_world_2d().direct_space_state.intersect_shape(query):
			if hit.collider == hurtbox: return true
	return false


func _cardinal(direction: Vector2) -> Vector2:
	if absf(direction.x) > absf(direction.y):
		return Vector2(signf(direction.x), 0)
	return Vector2(0, signf(direction.y)) if direction.y != 0.0 else Vector2.DOWN


func _jump_pressed(gravity: Vector2) -> bool:
	return Input.is_action_just_pressed(_jump_action(gravity))


func _jump_action(gravity: Vector2) -> StringName:
	if gravity == Vector2.DOWN: return &"ui_up"
	if gravity == Vector2.UP: return &"ui_down"
	if gravity == Vector2.LEFT: return &"ui_right"
	return &"ui_left"


func _at_arena_floor(gravity: Vector2) -> bool:
	if arena.size == Vector2.ZERO: return false
	var low := arena.position + Vector2(8, 8)
	var high := arena.end - Vector2(8, 8)
	if gravity == Vector2.DOWN: return global_position.y >= high.y - 0.1
	if gravity == Vector2.UP: return global_position.y <= low.y + 0.1
	if gravity == Vector2.LEFT: return global_position.x <= low.x + 0.1
	return global_position.x >= high.x - 0.1


func clamp_to_arena() -> void:
	if not arena_polygon.is_empty():
		if not Geometry2D.is_point_in_polygon(global_position, arena_polygon):
			var nearest := Vector2.ZERO
			var best := INF
			for i in range(arena_polygon.size()):
				var a := arena_polygon[i]
				var b := arena_polygon[(i + 1) % arena_polygon.size()]
				var point := Geometry2D.get_closest_point_to_segment(global_position, a, b)
				var distance := point.distance_squared_to(global_position)
				if distance < best:
					best = distance
					var normal := Vector2(-(b-a).y, (b-a).x).normalized()
					nearest = point + (normal if Geometry2D.is_point_in_polygon(point + normal, arena_polygon) else -normal) * 6.0
			global_position = nearest
		return
	if arena.size != Vector2.ZERO:
		var margin := Vector2(8, 8)
		global_position = global_position.clamp(arena.position + margin, arena.end - margin)


func advance_invulnerability(delta: float) -> void:
	invulnerability_remaining = maxf(0.0, invulnerability_remaining - delta)
	if is_instance_valid(sprite):
		sprite.modulate.a = 0.35 if invulnerability_remaining > 0.0 and int(invulnerability_remaining * 12.0) % 2 == 0 else 1.0


func blocks_bullet(bullet_position: Vector2) -> bool:
	return blocks_bullet_at(bullet_position, global_position)


func blocks_bullet_at(bullet_position: Vector2, soul_position: Vector2) -> bool:
	if not has_mode("green"):
		return false
	var incoming := (bullet_position - soul_position).normalized()
	return incoming.dot(shield_direction) >= 0.7


func take_damage(amount: int) -> bool:
	if not movement_enabled or invulnerability_remaining > 0.0 or amount <= 0 or DebugService.invincible:
		return false
	var damage := maxi(1, amount - Global.player_get_defense())
	Global.player_set_hp(int(Global.player_data.hp) - damage)
	invulnerability_remaining = invulnerability_time
	hurt.emit(damage)
	if Global.player_data.hp <= 0:
		defeated.emit()
	return true


func take_karma(amount: int) -> bool:
	if not movement_enabled or amount <= 0 or DebugService.invincible:
		return false
	Global.player_data.kr = minf(float(Global.player_data.kr) + amount, maxf(float(Global.player_data.hp) - 1.0, 0.0))
	Global.player_stats_changed.emit()
	return true


func advance_karma(delta: float) -> void:
	if float(Global.player_data.kr) <= 0.0 or int(Global.player_data.hp) <= 1:
		karma_timer = 0.0
		return
	karma_timer += delta * karma_per_second
	while karma_timer + 0.000001 >= 1.0 and float(Global.player_data.kr) >= 1.0 and int(Global.player_data.hp) > 1:
		karma_timer = maxf(0.0, karma_timer - 1.0)
		Global.player_data.kr = maxf(0.0, float(Global.player_data.kr) - 1.0)
		Global.player_set_hp(int(Global.player_data.hp) - 1)


func _draw() -> void:
	if has_mode("green") and movement_enabled:
		var center := shield_direction * 13.0
		var side := Vector2(-shield_direction.y, shield_direction.x) * 10.0
		draw_line(center - side, center + side, Color.LIME_GREEN, 3.0)
