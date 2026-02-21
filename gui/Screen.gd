class_name Screen extends Control

var _button_groups: Array = []
var _group_active_indices: Array = []
var _active_group_index: int = 0
var _active: bool = false

func add_button(button_obj: Node, on_unselect: Callable, on_select: Callable, on_click: Callable, group_index: int = 0) -> int:
	_ensure_group(group_index)
	var group_buttons = _button_groups[group_index]
	group_buttons.append({
		"button": button_obj,
		"on_unselect": on_unselect,
		"on_select": on_select,
		"on_click": on_click
	})
	_button_groups[group_index] = group_buttons
	if _group_active_indices[group_index] == -1:
		_group_active_indices[group_index] = 0
		if _active and group_index == _active_group_index:
			if on_select.is_valid():
				on_select.call()
	return group_buttons.size() - 1

func clear_buttons() -> void:
	_button_groups.clear()
	_group_active_indices.clear()
	_active_group_index = 0

func set_active(enable: bool) -> void:
	_active = enable

func is_active() -> bool:
	return _active

func get_active_button_index() -> int:
	if _active_group_index < 0 or _active_group_index >= _group_active_indices.size():
		return -1
	return _group_active_indices[_active_group_index]

func get_active_group_index() -> int:
	return _active_group_index

func get_active_button() -> Node:
	var group_buttons = _get_active_group_buttons()
	if group_buttons.is_empty():
		return null
	var index = get_active_button_index()
	if index < 0 or index >= group_buttons.size():
		return null
	return group_buttons[index]["button"]

func sync_active_index(index: int) -> void:
	var group_buttons = _get_active_group_buttons()
	if group_buttons.is_empty():
		return
	var new_index = clampi(index, 0, group_buttons.size() - 1)
	_group_active_indices[_active_group_index] = new_index

func set_active_group(index: int) -> void:
	_ensure_group(index)
	if _active_group_index == index:
		return
	var current_buttons = _get_active_group_buttons()
	var current_index = get_active_button_index()
	if current_index >= 0 and current_index < current_buttons.size():
		var current = current_buttons[current_index]
		var on_unselect = current["on_unselect"]
		if on_unselect.is_valid():
			on_unselect.call()
	_active_group_index = index
	var next_buttons = _get_active_group_buttons()
	if next_buttons.is_empty():
		_group_active_indices[_active_group_index] = -1
		return
	_group_active_indices[_active_group_index] = 0
	if _active:
		var selected = next_buttons[0]
		var on_select = selected["on_select"]
		if on_select.is_valid():
			on_select.call()

func handle_input(event: InputEvent) -> void:
	if not _active:
		return
	var group_buttons = _get_active_group_buttons()
	if group_buttons.is_empty():
		return
	if event.is_action_pressed("ui_left"):
		navigate(-1)
	elif event.is_action_pressed("ui_right"):
		navigate(1)
	elif event.is_action_pressed("ui_accept"):
		click_active()

func navigate(offset: int) -> void:
	_select_index(get_active_button_index() + offset)

func click_active() -> void:
	_click_active()

func _select_index(index: int) -> void:
	var group_buttons = _get_active_group_buttons()
	if group_buttons.is_empty():
		return
	var new_index = index
	if new_index < 0:
		new_index = group_buttons.size() - 1
	elif new_index >= group_buttons.size():
		new_index = 0
	var current_index = get_active_button_index()
	if new_index == current_index:
		return
	if current_index >= 0 and current_index < group_buttons.size():
		var current = group_buttons[current_index]
		var on_unselect = current["on_unselect"]
		if on_unselect.is_valid():
			on_unselect.call()
	_group_active_indices[_active_group_index] = new_index
	var selected = group_buttons[new_index]
	var on_select = selected["on_select"]
	if on_select.is_valid():
		on_select.call()

func _click_active() -> void:
	var group_buttons = _get_active_group_buttons()
	if group_buttons.is_empty():
		return
	var index = get_active_button_index()
	if index < 0 or index >= group_buttons.size():
		return
	var selected = group_buttons[index]
	var on_click = selected["on_click"]
	if on_click.is_valid():
		on_click.call()

func _ensure_group(index: int) -> void:
	if index < 0:
		return
	while _button_groups.size() <= index:
		_button_groups.append([])
		_group_active_indices.append(-1)
	if _active_group_index >= _button_groups.size():
		_active_group_index = 0

func _get_active_group_buttons() -> Array:
	if _active_group_index < 0 or _active_group_index >= _button_groups.size():
		return []
	return _button_groups[_active_group_index]
