class_name BattleSoulRed extends CharacterBody2D

signal hurt(damage: int)
signal defeated

@export var speed: float = 180.0 # pixels per second
@export var invulnerability_time: float = 1.0 # seconds
@onready var sprite: AnimatedSprite2D = $sprite

var movement_enabled := false
var arena := Rect2()
var invulnerability_remaining := 0.0


func _physics_process(delta: float) -> void:
	advance_invulnerability(delta)
	if not movement_enabled:
		velocity = Vector2.ZERO
		return
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_action_pressed("ui_cancel"):
		direction *= 0.5
	velocity = direction * speed
	# CharacterBody2D applies the physics delta inside move_and_slide().
	move_and_slide()
	clamp_to_arena()


func clamp_to_arena() -> void:
	if arena.size == Vector2.ZERO:
		return
	var margin := Vector2(8.0, 8.0)
	global_position = global_position.clamp(arena.position + margin, arena.end - margin)


func advance_invulnerability(delta: float) -> void:
	invulnerability_remaining = maxf(0.0, invulnerability_remaining - delta)
	if is_instance_valid(sprite):
		sprite.modulate.a = 0.35 if invulnerability_remaining > 0.0 and int(invulnerability_remaining * 12.0) % 2 == 0 else 1.0


func take_damage(amount: int) -> bool:
	if not movement_enabled or invulnerability_remaining > 0.0 or amount <= 0:
		return false
	Global.player_set_hp(int(Global.player_data.hp) - amount)
	invulnerability_remaining = invulnerability_time
	hurt.emit(amount)
	if Global.player_data.hp <= 0:
		defeated.emit()
	return true
