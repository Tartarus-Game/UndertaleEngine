extends BattleEnemy

const BONES_WAVE := preload("res://examples/custom_enemy/bones_wave.tscn")
const PELLETS_WAVE := preload("res://examples/custom_enemy/pellets_wave.tscn")

var encouragement_count := 0


func init() -> void:
	super.init()
	action_set(1, "Encourage", _encourage)


func _encourage() -> String:
	encouragement_count += 1
	if encouragement_count >= 2:
		spareable = true
		return "* The guide is confident enough to leave."
	return "* You encourage the guide. They still seem nervous."


func get_turn_dialog() -> String:
	return "* The guide prepares a different lesson."


func get_wave_scene(turn: int) -> PackedScene:
	return BONES_WAVE if turn % 2 == 1 else PELLETS_WAVE
