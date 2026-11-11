extends Node

@onready var SEP: AudioStreamPlayer = $SoundEffectsPlayer
@onready var BGMP: AudioStreamPlayer = $BGMPlayer
@onready var sounds := {PLAYER.SOUND_EFFECT: SEP, PLAYER.BGM: BGMP}
enum PLAYER { SOUND_EFFECT, BGM }


func set_audio_volume(value: float, type := PLAYER.SOUND_EFFECT) -> void:
	if not sounds.has(type): return
	var player: AudioStreamPlayer = sounds[type]
	player.volume_db = value
	if type == PLAYER.SOUND_EFFECT:
		for voice in get_tree().get_nodes_in_group("audio_sfx_voices"):
			voice.volume_db = value


func play_sound_with_pitch(sound: AudioStream, pitch: float, type := PLAYER.SOUND_EFFECT) -> void:
	if sound == null or not sounds.has(type): return
	var player: AudioStreamPlayer
	if type == PLAYER.SOUND_EFFECT:
		player = AudioStreamPlayer.new()
		player.volume_db = SEP.volume_db
		player.add_to_group("audio_sfx_voices")
		add_child(player)
		player.finished.connect(player.queue_free)
	else:
		player = BGMP
	player.pitch_scale = pitch
	player.stream = sound
	player.stream_paused = false
	player.play()


func play_sound(sound: AudioStream, type := PLAYER.SOUND_EFFECT) -> void:
	play_sound_with_pitch(sound, 1.0, type)


func crossfade_music(sound: AudioStream, seconds: float = 0.5) -> void:
	if sound == null: return
	var previous := BGMP
	var next := AudioStreamPlayer.new()
	add_child(next)
	next.stream = sound
	var target_db := previous.volume_db
	next.volume_db = -80.0
	next.play()
	BGMP = next
	sounds[PLAYER.BGM] = next
	var tween := create_tween().set_parallel(true)
	tween.tween_property(previous, "volume_db", -80.0, maxf(seconds, 0.001))
	tween.tween_property(next, "volume_db", target_db, maxf(seconds, 0.001))
	await tween.finished
	if is_instance_valid(previous): previous.queue_free()


func toggle_pause(type := PLAYER.SOUND_EFFECT) -> void:
	if not sounds.has(type): return
	var player: AudioStreamPlayer = sounds[type]
	player.stream_paused = not player.stream_paused


func stop_all_sfx() -> void:
	if is_instance_valid(SEP):
		SEP.stop()
	for voice in get_tree().get_nodes_in_group("audio_sfx_voices"):
		if voice.get_parent() == self:
			voice.stop()
			voice.stream = null
			voice.queue_free()


func _exit_tree() -> void:
	stop_all_sfx()
	if is_instance_valid(BGMP): BGMP.stop()
