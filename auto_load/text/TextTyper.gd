class_name TextTyper extends RichTextLabel

# Time between characters, in seconds. Unspent time is carried into the next frame.
var delta_time: float = 0.05
var delta_timer: float = 0.0
var sleep: float = 0.0
var skip_able: bool = true
var pause: bool = false
var typer_uid: int = -1
var texts: Array = []
var current_text: Dictionary = {}

@export var sound: AudioStream


func text_add(value: String, function: Callable = Callable()) -> TextTyper:
	texts.append({"text": value, "callable": function})
	return self


func _process(delta: float) -> void:
	if pause and visible_characters >= get_total_character_count() and Input.is_action_just_pressed("ui_accept"):
		resume_text()
		return
	if skip_able and Input.is_action_just_pressed("ui_cancel"):
		skip()
		return
	advance_text(delta)


# Exposed so a cutscene or a test can advance the typer with a supplied timestep.
func advance_text(delta: float) -> void:
	# -1 is RichTextLabel's built-in setting for displaying all text.
	if visible_characters < 0:
		if texts.is_empty():
			return
		visible_characters = get_total_character_count()
	var remaining := maxf(delta, 0.0)
	while true:
		if visible_characters >= get_total_character_count():
			if pause or texts.is_empty():
				delta_timer = 0.0
				return
			next_text()

		if sleep > 0.0:
			var elapsed := minf(sleep, remaining)
			sleep -= elapsed
			remaining -= elapsed
			if sleep > 0.0:
				return

		if delta_time <= 0.0:
			visible_characters = get_total_character_count()
			continue

		var needed := maxf(delta_time - delta_timer, 0.0)
		if remaining + 0.000001 < needed:
			delta_timer += remaining
			return
		remaining = maxf(remaining - needed, 0.0)
		delta_timer = 0.0
		visible_characters += 1
		if sound:
			AudioManager.play_sound(sound)


func is_typing() -> bool:
	return (visible_characters >= 0 and visible_characters < get_total_character_count()) or (not pause and not texts.is_empty())


func skip() -> void:
	sleep = 0.0
	delta_timer = 0.0
	visible_characters = get_total_character_count()
	while not pause and not texts.is_empty():
		next_text()
		visible_characters = get_total_character_count()


func next_text() -> void:
	if texts.is_empty():
		return
	current_text = texts.pop_front()
	text += current_text.text
	var callback: Callable = current_text.callable
	if callback.is_valid():
		callback.call(self)


func clear_text() -> void:
	texts.clear()
	current_text.clear()
	visible_characters = 0
	text = ""
	delta_timer = 0.0
	sleep = 0.0
	pause = false


func pause_text() -> void:
	pause = true


func resume_text() -> void:
	pause = false


func sleep_text(time: float) -> void:
	sleep = maxf(time, 0.0)
