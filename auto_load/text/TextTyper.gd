class_name TextTyper extends RichTextLabel;
var texts = [];
var current_text : Dictionary = {};
var delta_time : float = 0.05;
var delta_timer : float = 0;
var sleep : float = 0;
var skip_able : bool = true;
var pause : bool = false;
var typer_uid : int = -1;

@export var sound : AudioStream;

"""
text_add("text0",func(typer): typer.clear_text());
"""

func text_add(_text : String, function : Callable) -> TextTyper:
	var typer_text = {};
	typer_text.set("text", _text);
	typer_text.set("callable", function);
	texts.append(typer_text);
	return self;

func _process(_delta: float) -> void:
	if(get_total_character_count() == visible_characters and !pause):
		if(len(texts)>0):
			next_text();
		return;
	elif(get_total_character_count() == visible_characters):
		if(Input.is_action_just_pressed("ui_accept")): next_text();
		return;
	if(sleep > 0):
		sleep -= _delta
		return;
	if(delta_timer < delta_time):
		delta_timer += _delta;
		return;
	else:
		if(sound): AudioManager.play_sound(sound);
		delta_timer = 0;
		visible_characters += 1
	if(skip_able):
		if(Input.is_action_pressed("ui_cancel")): 
			skip();
		
		
func skip():
	# 先把当前正在滚动的文字立即显示完整。
	visible_characters = get_total_character_count()
	# 再穿透所有不需要暂停的后续条目。
	while len(texts) > 0 and not pause:
		next_text()
		visible_characters = get_total_character_count()

func next_text():
	if(len(texts)==0): return;
	current_text = texts[0];
	text += texts[0].text;
	texts[0].callable.call(self);
	if(len(texts)==0): return;
	texts.remove_at(0);
	return;
	
func clear_text():
	visible_characters = 0;
	text = "";
	return;
		
func pause_text():
	pause = true;
	return;

func sleep_text(time : float):
	sleep = time;
	return;


func _exit_tree() -> void:
	pass;
