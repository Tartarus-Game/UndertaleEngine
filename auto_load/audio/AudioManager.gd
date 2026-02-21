extends Node
@onready var SEP = $SoundEffectsPlayer
@onready var BGMP = $BGMPlayer
@onready var sounds = {
	PLAYER.SOUND_EFFECT : SEP,
	PLAYER.BGM : BGMP
}
enum PLAYER{
	SOUND_EFFECT,
	BGM
}

func set_audio_volume(value : float,type = PLAYER.SOUND_EFFECT):
	if(!sounds.has(type)): return;
	var player : AudioStreamPlayer = sounds[type];
	player.volume_db = value;

func play_sound_with_pitch(sound : AudioStream, pitch : float = 1, type = PLAYER.SOUND_EFFECT):
	if(!sound): return;
	if(!sounds.has(type)): return;
	var player : AudioStreamPlayer = AudioStreamPlayer.new();
	player.pitch_scale = pitch;
	player.stream = sound;
	add_child(player)
	player.play();
	
	await player.finished
	player.queue_free()

func play_sound(sound : AudioStream, type = PLAYER.SOUND_EFFECT):
	play_sound_with_pitch(sound, 1, type)

func toggle_pause(type = PLAYER.SOUND_EFFECT):
	if(!sounds.has(type)): return;
	var player : AudioStreamPlayer = sounds[type];
	player.stream_paused = !player.stream_paused;
