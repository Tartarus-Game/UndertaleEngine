extends Node

var dialogue = [];

func add_dialogue(text : String, callable : Callable):
	dialogue.append({"text": text, "callable": callable});

func enqueue_dialogue():
	var text = dialogue[0];
	dialogue.remove_at(0);
	return text;

func get_dialogue_size():
	return len(dialogue);
