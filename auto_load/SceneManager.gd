extends CanvasLayer;
@onready var fader = $Fader;

var current_scene : PackedScene;

func goto_scene_to_path(path : String):
	if(!FileAccess.file_exists(path)): return;
	current_scene = load(path);
	return get_tree().change_scene_to_file(path);

func goto_scene_to_packed(packed : PackedScene):
	current_scene = packed;
	return get_tree().change_scene_to_packed(packed);

func change_scene_to_path(path : String):
	if(!FileAccess.file_exists(path)): return;
	fader.visible = true
	var t = create_tween().set_ease(Tween.EASE_OUT_IN).set_trans(Tween.TRANS_LINEAR);
	t.tween_property(fader, "modulate:a", 1.0, 0.5);
	await t.finished
	goto_scene_to_path(path);
	var fade_out = create_tween()
	fade_out.tween_property(fader, "modulate:a", 0.0, 0.5)
	await fade_out.finished
	fader.visible = false
	return;

func fade(duration : float, intime : float, outtime : float):
	fader.visible = true;
	var t = create_tween().set_ease(Tween.EASE_OUT_IN).set_trans(Tween.TRANS_LINEAR);
	t.tween_property(fader, "modulate:a", 1.0, intime);
	t.tween_property(fader, "modulate:a", 0.0, outtime).set_delay(duration);
	await t.finished;
	fader.visible = false;
	return;

func is_battle():
	return current_scene != null and current_scene.resource_path == "res://battle/Battle.tscn";

func _encounter_animation_start():
	goto_scene_to_path("res://battle/Battle.tscn");
	
