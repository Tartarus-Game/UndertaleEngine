@tool extends CharacterBody2D

@export var box : Panel;
@export var size : Vector2 = Vector2(100, 100);
@export var Left : CollisionShape2D;
@export var Right : CollisionShape2D;
@export var Down : CollisionShape2D;
@export var Up : CollisionShape2D;
@export var frame_width : float = 5;

var _active_tween : Tween
	
func resize(target_size: Vector2, target_position: Vector2, duration: float = 0.5) -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	
	_active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "size", target_size, duration)
	_active_tween.tween_property(self, "position", target_position, duration)

func _physics_process(_delta: float) -> void:
	Left.position = - Vector2(size.x/2-frame_width/2, -frame_width/2);
	Left.scale.y = (size.y + frame_width) / 50;
	Right.position = Vector2(size.x/2+frame_width/2, frame_width/2);
	Right.scale.y = (size.y + frame_width) / 50;
	Up.position =  - Vector2(- frame_width/2, size.y/2-frame_width/2);
	Up.scale.y = (size.x + frame_width) / 50;
	Down.position = Vector2(frame_width/2, size.y/2+frame_width/2);
	Down.scale.y = (size.x + frame_width) / 50;
	box.size = size + Vector2(frame_width,frame_width);
	box.position = -size/2;
