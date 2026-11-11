class_name ScreenManagerNode extends Node

var _screens : Array[Screen] = []
var _active_screen : Screen = null

func register_screen(screen: Screen) -> void:
	if screen == null:
		return
	if _screens.has(screen):
		return
	_screens.append(screen)
	if _active_screen == null:
		set_active_screen(screen)

func unregister_screen(screen: Screen) -> void:
	if screen == null:
		return
	if _active_screen == screen:
		_active_screen.set_active(false)
		_active_screen = null
	_screens.erase(screen)

func set_active_screen(screen: Screen) -> void:
	if screen == null:
		return
	if _active_screen == screen:
		return
	if _active_screen != null:
		_active_screen.set_active(false)
	_active_screen = screen
	_active_screen.set_active(true)

func get_active_screen() -> Screen:
	return _active_screen

func _unhandled_input(event: InputEvent) -> void:
	if _active_screen == null:
		return
	_active_screen.handle_input(event)
