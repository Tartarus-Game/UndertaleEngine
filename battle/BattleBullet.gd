class_name BattleBullet extends CharacterBody2D

@export var CS2D : CollisionShape2D

func _ready() -> void:
	collision_layer = Global.BATTLE_SOUL_COLLISION_LAYER

func _physics_process(_delta: float) -> void:
	move_and_slide()

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if(collider.has_method("hurt")):
			collider.hurt()
				
