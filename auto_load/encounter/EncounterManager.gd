extends Node

signal battle_finished(result: String)

var current_id: int = -1
var encounters := {
	-1: [preload("res://battle/enemy/BattleEnemy.tscn"), preload("res://battle/enemy/test/battle_enemy_test.tscn")]
}
var encounter_texts := {-1: "* Two strange creatures appeared."}
var battle_soul: BattleSoulRed
var return_scene_path := ""
var last_result := ""
var _suspended_scene: Node
var _active_encounter := false
var encounter_music := {}
var _previous_music: AudioStream
var _previous_music_position := 0.0
var _previous_music_playing := false
var _previous_music_paused := false


func encounter(id: int, animation: bool = true) -> void:
	if not encounters.has(id) or _active_encounter:
		return
	current_id = id
	_suspended_scene = get_tree().current_scene
	return_scene_path = _suspended_scene.scene_file_path if _suspended_scene else ""
	last_result = ""
	_active_encounter = true
	if animation:
		call_deferred("_transition_to_battle")
	else:
		call_deferred("_start_battle")


func _transition_to_battle() -> void:
	var fader: ColorRect = SceneManager.fader
	fader.visible = true
	fader.modulate.a = 0.0
	var fade := SceneManager.create_tween()
	fade.tween_property(fader, "modulate:a", 1.0, 0.16)
	await fade.finished
	if not _active_encounter: return
	_start_battle()
	var fade_in := SceneManager.create_tween()
	fade_in.tween_property(fader, "modulate:a", 0.0, 0.16)
	await fade_in.finished
	fader.visible = false


func _start_battle() -> void:
	var tree := get_tree()
	var bgm: AudioStreamPlayer = AudioManager.BGMP
	_previous_music = bgm.stream
	_previous_music_playing = bgm.playing
	_previous_music_paused = bgm.stream_paused
	_previous_music_position = bgm.get_playback_position() if bgm.playing else 0.0
	if encounter_music.has(current_id):
		AudioManager.play_sound(encounter_music[current_id], AudioManager.PLAYER.BGM)
	elif bgm.playing:
		bgm.stream_paused = true
	if is_instance_valid(_suspended_scene):
		tree.root.remove_child(_suspended_scene)
	var scene: PackedScene = load("res://battle/Battle.tscn")
	var battle := scene.instantiate()
	tree.root.add_child(battle)
	tree.current_scene = battle
	SceneManager.current_scene = scene


func encounter_get(id: int):
	return encounters.get(id)


func encounter_set(id: int, enemy0: PackedScene, enemy1: PackedScene = null, enemy2: PackedScene = null, encounter_text: String = "") -> void:
	encounters[id] = [enemy0, enemy1, enemy2]
	encounter_texts[id] = encounter_text


func set_encounter_music(id: int, stream: AudioStream) -> void:
	encounter_music[id] = stream


func get_current_encounter() -> Array:
	var enemies: Array = []
	for scene in encounters.get(current_id, []):
		if scene != null:
			enemies.append(scene)
	return enemies


func get_current_encounter_enemys() -> Array:
	return get_current_encounter()


func get_current_encounter_text() -> String:
	return encounter_texts.get(current_id, "")


func get_soul() -> BattleSoulRed:
	return battle_soul


func finish_battle(result: String) -> void:
	if not _active_encounter:
		return
	_active_encounter = false
	call_deferred("_restore_scene", result)


func _restore_scene(result: String) -> void:
	var tree := get_tree()
	var battle := tree.current_scene
	if battle:
		tree.root.remove_child(battle)
		battle.queue_free()
	if is_instance_valid(_suspended_scene):
		tree.root.add_child(_suspended_scene)
		tree.current_scene = _suspended_scene
		if not return_scene_path.is_empty():
			SceneManager.current_scene = load(return_scene_path)
	_suspended_scene = null
	battle_soul = null
	var bgm: AudioStreamPlayer = AudioManager.BGMP
	if encounter_music.has(current_id):
		bgm.stop()
		bgm.stream = _previous_music
		if _previous_music_playing and _previous_music:
			bgm.play(_previous_music_position)
			bgm.stream_paused = _previous_music_paused
	elif _previous_music_playing:
		bgm.stream_paused = _previous_music_paused
	last_result = result
	if result == "lost":
		await GameOverService.show_game_over()
	battle_finished.emit(result)
