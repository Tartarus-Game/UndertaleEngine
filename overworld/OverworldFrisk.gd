class_name OverworldFrisk extends OverworldChar

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_ray: RayCast2D = $RayCast2D

var facing := Vector2.DOWN


func _ready() -> void:
	add_to_group("overworld_player")
	interaction_ray.collide_with_bodies = false
	interaction_ray.collide_with_areas = true
	interaction_ray.hit_from_inside = true
	interaction_ray.collision_mask = 8
	_update_animation(Vector2.ZERO)


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") if movement_enabled else Vector2.ZERO
	if direction != Vector2.ZERO:
		if absf(direction.x) > absf(direction.y):
			facing = Vector2(signf(direction.x), 0)
		else:
			facing = Vector2(0, signf(direction.y))
	move(direction)
	super(delta)
	_update_animation(direction)


func _unhandled_input(event: InputEvent) -> void:
	if movement_enabled and event.is_action_pressed("ui_accept") and not event.is_echo():
		interaction_ray.target_position = facing * 32.0
		interaction_ray.force_raycast_update()
		var target := interaction_ray.get_collider()
		if target is OverworldTrigger:
			target.interact(self)
			get_viewport().set_input_as_handled()


func _update_animation(direction: Vector2) -> void:
	var state := "move_" if direction != Vector2.ZERO else "idle_"
	var face := "down"
	if facing.y < 0: face = "up"
	elif facing.x < 0: face = "left"
	elif facing.x > 0: face = "right"
	sprite.flip_h = facing.x > 0
	sprite.play(state + face)
