class_name BattleFightAim extends Node2D

signal attack_finished(damage_multiplier: float)

var active := false
var cursor_pos := 0.0
var move_speed := 600.0
var bg_texture: Texture2D

var _finished := false
var _blink_timer := 0.0
var _blink_visible := true

func _ready():
	bg_texture = load("res://resources/battle/UI/spr_target_0.png")
	hide()

func start():
	position = Vector2(320, 320)
	show()
	active = true
	_finished = false
	_blink_timer = 0.0
	_blink_visible = true
	if bg_texture:
		cursor_pos = - bg_texture.get_width() / 2.0 - 10.0
	queue_redraw()
	
func _process(delta: float):
	if not visible:
		return
		
	if active:
		cursor_pos += move_speed * delta
		queue_redraw()
		if bg_texture and cursor_pos > bg_texture.get_width() / 2.0 + 10.0:
			_finish(true)
	elif _finished:
		_blink_timer += delta
		if _blink_timer > 0.1:
			_blink_timer = 0.0
			_blink_visible = not _blink_visible
			queue_redraw()

func handle_input(event: InputEvent) -> void:
	if active:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			_finish(false)

func _finish(miss: bool = false):
	active = false
	_finished = true
	_blink_visible = true
	queue_redraw()
	
	var mult = 0.0
	if not miss and bg_texture:
		var max_dist = bg_texture.get_width() / 2.0
		var dist = abs(cursor_pos)
		mult = clampf(1.0 - (dist / max_dist), 0.0, 1.0)
		# Tweak curve, e.g. center 10 pixels is 100% damage
		if dist < 12.0:
			mult = 1.0
	
	# Wait a bit so the player can see where they stopped
	var t = create_tween()
	t.tween_interval(0.6)
	t.tween_callback(func():
		hide()
		_finished = false
		attack_finished.emit(mult)
	)

func _draw():
	if not bg_texture:
		return
	
	var bg_size = bg_texture.get_size()
	draw_texture(bg_texture, -bg_size / 2.0)
	
	# Draw cursor
	if _blink_visible:
		var bar_width = 14.0
		var bar_height = bg_size.y + 16.0
		var rect_black = Rect2(cursor_pos - bar_width / 2.0, -bar_height / 2.0, bar_width, bar_height)
		var rect_white = rect_black.grow(-3.0)
		draw_rect(rect_black, Color.BLACK)
		draw_rect(rect_white, Color.WHITE)
