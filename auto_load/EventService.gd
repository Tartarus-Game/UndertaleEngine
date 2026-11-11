extends Node

signal event_finished
var running := false
var _event_actor: OverworldChar

# Commands: dialogue, choice, wait, move, set_flag, if_flag, warp, encounter, call.
func run(steps: Array, actor: OverworldChar = null) -> void:
	if running: return
	running = true
	var was_enabled := actor.movement_enabled if is_instance_valid(actor) else false
	_event_actor = actor
	if is_instance_valid(actor): actor.movement_enabled = false
	await _run_steps(steps, actor)
	if is_instance_valid(_event_actor): _event_actor.movement_enabled = was_enabled
	_event_actor = null
	running = false
	event_finished.emit()


func _run_steps(steps: Array, actor: OverworldChar) -> void:
	for value in steps:
		var step: Dictionary = value
		match str(step.get("type", "")):
			"dialogue":
				await DialogueService.present(str(step.get("text", "")), [], step.get("portrait"))
			"choice":
				var choice: int = await DialogueService.present(str(step.get("text", "")), step.get("options", []))
				Global.set_flag(str(step.get("flag", "choice")), choice)
			"wait":
				await get_tree().create_timer(maxf(0.0, float(step.get("seconds", 0.0)))).timeout
			"move":
				var character: Node2D = step.get("node", _event_actor)
				if is_instance_valid(character):
					var tween := create_tween()
					tween.tween_property(character, "global_position", step.get("to", character.global_position), maxf(0.001, float(step.get("seconds", 1.0))))
					await tween.finished
			"set_flag":
				Global.set_flag(str(step.get("key", "")), step.get("value"))
			"if_flag":
				var condition: bool = Global.get_flag(str(step.get("key", ""))) == step.get("value")
				await _run_steps(step.get("then", []) if condition else step.get("else", []), actor)
			"warp":
				var path := str(step.get("scene", ""))
				if await OverworldManager.change_room(path, step.get("position")):
					var player := OverworldManager.get_player()
					if player:
						_event_actor = player
						_event_actor.movement_enabled = false
						actor = _event_actor
			"encounter":
				var encounter_id := int(step.get("id", -1))
				if EncounterManager.encounter_get(encounter_id) != null:
					EncounterManager.encounter(encounter_id, bool(step.get("animation", true)))
					var result: String = await EncounterManager.battle_finished
					if result == "lost": return
			"call":
				var action: Callable = step.get("action", Callable())
				if action.is_valid(): await action.call()
