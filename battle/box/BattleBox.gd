@tool extends CharacterBody2D

@export var box : Panel;
@export var size : Vector2 = Vector2(100, 100);
@export var Left : CollisionShape2D;
@export var Right : CollisionShape2D;
@export var Down : CollisionShape2D;
@export var Up : CollisionShape2D;
@export var frame_width : float = 2;

func _physics_process(_delta: float) -> void:
	Left.position = - Vector2(size.x/2-frame_width/2, 0);
	Left.scale.y = size.y/50;
	Left.scale.x = 1;
	Right.position = Vector2(size.x/2-frame_width/2, 0);
	Right.scale.y = size.y/50;
	Right.scale.x = 1;
	Up.position = Vector2(0, size.y/2-frame_width/2);
	Up.scale.y = size.x/50;
	Up.scale.x = 1;
	Down.position = - Vector2(0, size.y/2-frame_width/2);
	Down.scale.y = size.x/50;
	Down.scale.x = 1;
	box.size = size;
	box.position = -size/2;
