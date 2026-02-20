extends Control
@onready var box = $Box
@onready var anim = $Box/anim
@onready var left = $Left
@onready var right = $Right
@onready var typer = $Box/TextTyper;

@export var width : float = 343;
@export var height : float = 103;
@export var animation : bool = true;

var current_width : float = 0;

func _process(delta: float) -> void:
	left.size = Vector2(12, height + 14);
	left.position = Vector2(- current_width/2 - 12, -7);
	right.size = Vector2(12, height + 14);
	right.position = Vector2(current_width/2, -7);
	#box.size = Vector2(current_width, height);
	box.position = Vector2(- current_width/2, 0);

func _ready() -> void:
	position = Vector2(320,300);
	typer.text_add("This is a test text", func(_typer): _typer.pause_text());
	if(animation): _animation();

func _animation():
	anim.size = Vector2(0, height);
	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO).set_parallel(true);
	t.tween_property(self, "current_width", width, 0.5);
	t.tween_property(anim, "size", Vector2(width, height), 0.5).set_delay(0.05);
	t.tween_property(anim, "position", Vector2(width + 1, 0), 0.5).set_delay(0.2);
