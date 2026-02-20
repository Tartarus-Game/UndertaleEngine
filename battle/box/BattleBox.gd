@tool extends CharacterBody2D

@export var box : Panel;
@export var size : Vector2 = Vector2(100, 100);
@export var Left : CollisionShape2D;
@export var Right : CollisionShape2D;
@export var Down : CollisionShape2D;
@export var Up : CollisionShape2D;
@export var frame_width : float = 2;


func _physics_process(_delta: float) -> void:
	Left.position = position - Vector2(size.x/2-frame_width/2, 0);
	Left.scale.y = 50/size.y;
	Right.position = position + Vector2(size.x/2-frame_width/2, 0);
	Right.scale.y = 50/size.y;
	Up.position = position - Vector2(0, size.y/2-frame_width/2);
	Up.scale.x = 50/size.x;
	Down.position = position + Vector2(0, size.y/2-frame_width/2);
	Down.scale.x = 50/size.x;
	box.size = size;
	box.position = -size/2;
