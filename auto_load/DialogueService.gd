extends CanvasLayer

signal completed(choice: int)
var busy := false
var options: Array[String] = []
var selected := 0
var armed := false
var panel: Panel
var typer: TextTyper
var choices: Label
var portrait: TextureRect
var _actor: OverworldChar
var _actor_was_enabled := false


func _ready() -> void:
	layer = 30
	visible = false
	panel = Panel.new()
	panel.position = Vector2(24, 290)
	panel.size = Vector2(592, 165)
	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.border_color = Color.WHITE
	style.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	portrait = TextureRect.new()
	portrait.position = Vector2(15, 15)
	portrait.size = Vector2(80, 80)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(portrait)
	typer = preload("res://auto_load/text/TextTyper.tscn").instantiate()
	typer.position = Vector2(20, 15)
	typer.size = Vector2(550, 95)
	typer.fit_content = false
	typer.scroll_active = true
	panel.add_child(typer)
	typer.set_process(false)
	choices = Label.new()
	choices.position = Vector2(20, 112)
	choices.size = Vector2(550, 40)
	choices.add_theme_font_size_override("font_size", 18)
	var choice_font := FontVariation.new()
	choice_font.base_font = load("res://font/DTM-momo.otf")
	choice_font.fallbacks = [load("res://font/SIMSUNB.TTF")]
	choices.add_theme_font_override("font", choice_font)
	panel.add_child(choices)


func present(message: String, choices_list: Array = [], face: Texture2D = null) -> int:
	if busy:
		return -1
	busy = true
	armed = false
	selected = 0
	options.clear()
	for option in choices_list: options.append(str(option))
	var players := get_tree().get_nodes_in_group("overworld_player")
	_actor = players[0] if not players.is_empty() else null
	if is_instance_valid(_actor):
		_actor_was_enabled = _actor.movement_enabled
		_actor.movement_enabled = false
	portrait.texture = face
	portrait.visible = face != null
	typer.position.x = 110 if face else 20
	typer.size.x = 460 if face else 550
	typer.clear_text()
	typer.text_add_markup(message)
	typer.next_text()
	_update_choices()
	visible = true
	var result: int = await completed
	return result


func _process(delta: float) -> void:
	if not busy: return
	typer.advance_text(delta)
	if not Input.is_action_pressed("ui_accept") and not Input.is_action_pressed("ui_cancel"):
		armed = true


func _unhandled_input(event: InputEvent) -> void:
	if not busy or not armed: return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		if not options.is_empty(): selected = posmod(selected - 1, options.size())
		_update_choices()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		if not options.is_empty(): selected = posmod(selected + 1, options.size())
		_update_choices()
	elif event.is_action_pressed("ui_accept"):
		if typer.pause: typer.resume_text()
		elif typer.is_typing(): typer.skip()
		else: _finish(selected if not options.is_empty() else -1)
	elif event.is_action_pressed("ui_cancel"):
		if typer.is_typing(): typer.skip()
		else: return
	else:
		return
	get_viewport().set_input_as_handled()


func _update_choices() -> void:
	var text := ""
	for i in range(options.size()):
		text += ("  > " if i == selected else "    ") + options[i]
	choices.text = text


func _finish(result: int) -> void:
	visible = false
	busy = false
	if is_instance_valid(_actor): _actor.movement_enabled = _actor_was_enabled
	_actor = null
	completed.emit(result)
