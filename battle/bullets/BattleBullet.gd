class_name BattleBullet extends Area2D

enum Rule { WHITE, BLUE, ORANGE, HEAL }
@export var velocity := Vector2(-115.0, 0.0)
@export var damage := 3
@export var lifetime := 6.0
@export var rule: Rule = Rule.WHITE
@export var karma := false
@export var karma_per_second := 6.0
@export var destroy_on_contact := true
@export var shootable := false
@export var projectile_health := 1.0
var _contact_ticks: Dictionary = {}


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	if shootable:
		add_to_group("shootable_bullets")


func hit_by_soul_shot(amount: float) -> void:
	projectile_health -= amount
	if projectile_health <= 0.0:
		queue_free()


func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	# A soul may start or stop moving while it remains inside a bullet.
	for area in get_overlapping_areas():
		_try_contact(area, delta)


func _draw() -> void:
	var colors := [Color.WHITE, Color.CYAN, Color.ORANGE, Color.LIME_GREEN]
	draw_circle(Vector2.ZERO, 6.0, colors[rule])


func _on_area_entered(area: Area2D) -> void:
	_try_contact(area)


func _on_area_exited(area: Area2D) -> void:
	_contact_ticks.erase(area.get_instance_id())


func _try_contact(area: Area2D, delta: float = 0.0) -> void:
	if is_queued_for_deletion(): return
	var soul := area.get_parent()
	if not soul is BattleSoul or not soul.movement_enabled:
		return
	if rule == Rule.BLUE and not soul.is_moving: return
	if rule == Rule.ORANGE and soul.is_moving: return
	if soul.blocks_bullet(global_position):
		if destroy_on_contact: queue_free()
		return
	var applied := false
	var contact_id := area.get_instance_id()
	if rule == Rule.HEAL:
		if not _contact_ticks.has(contact_id):
			Global.player_heal(damage)
			_contact_ticks[contact_id] = 0.0
			applied = true
	elif karma or bool(Global.player_data.kr_enabled):
		if not _contact_ticks.has(contact_id):
			_contact_ticks[contact_id] = 0.0
			applied = soul.take_karma(damage)
		else:
			var accumulated := float(_contact_ticks[contact_id]) + karma_per_second * delta
			var amount := floori(accumulated + 0.000001)
			_contact_ticks[contact_id] = maxf(0.0, accumulated - amount)
			if amount > 0: applied = soul.take_karma(amount)
	else:
		applied = soul.take_damage(damage)
	if applied and destroy_on_contact:
		queue_free()
