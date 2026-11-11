extends Node

const SAVE_PATH := "user://saves/"


func show_game_over() -> void:
	var has_save := FileAccess.file_exists(SAVE_PATH.path_join("file" + str(Global.current_save_slot)))
	var choices := [SettingsService.text("gameover.load"), SettingsService.text("gameover.continue")] if has_save else [SettingsService.text("gameover.continue")]
	var choice: int = await DialogueService.present(SettingsService.text("gameover.text"), choices)
	if has_save and choice == 0:
		await Global.restore_world(SAVE_PATH, Global.current_save_slot)
	else:
		Global.player_data.kr = 0.0
		Global.player_set_hp(int(Global.player_data.hp_max))
