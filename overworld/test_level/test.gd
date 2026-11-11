extends Node2D

func _ready() -> void:
	if EncounterManager.last_result.is_empty():
		await get_tree().create_timer(0.1).timeout
		EncounterManager.encounter(-1)
	else:
		var label := Label.new()
		label.text = "Battle result: %s\nPress Z to start again." % EncounterManager.last_result
		label.position = Vector2(160, 200)
		add_child(label)

func _process(_delta: float) -> void:
	if not EncounterManager.last_result.is_empty() and Input.is_action_just_pressed("ui_accept"):
		Global.player_set_hp(int(Global.player_data.hp_max))
		EncounterManager.encounter(-1)
