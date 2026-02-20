@tool extends CharacterBody2D

@export var box : Panel;
@export var size : Vector2 = Vector2(100, 100);
@export var Left : CollisionShape2D;
@export var Right : CollisionShape2D;
@export var Down : CollisionShape2D;
@export var Up : CollisionShape2D;
@export var frame_width : float = 2;

var _active_tween : Tween

func resize(target_size: Vector2, target_position: Vector2, duration: float = 0.5) -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	
	_active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "size", target_size, duration)
	_active_tween.tween_property(self, "position", target_position, duration)

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
