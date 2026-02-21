extends SceneTree

var _passed := true

class Recorder:
	var items := []
	func record(value: String) -> void:
		items.append(value)

func _init() -> void:
	_run()
	if _passed:
		quit(0)
	else:
		quit(1)

func _run() -> void:
	_test_group_switch_selects_first()
	_test_navigation_stays_in_group()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_passed = false
		push_error(message)

func _make_button(label: String) -> Node:
	var node := Node.new()
	node.name = label
	return node

func _test_group_switch_selects_first() -> void:
	var screen := Screen.new()
	var recorder := Recorder.new()

	var button_a := _make_button("A")
	var button_b := _make_button("B")
	var button_c := _make_button("C")

	screen.set_active(true)
	screen.call("add_button", button_a, Callable(), Callable(recorder, "record").bind("A"), Callable(), 0)
	screen.call("add_button", button_b, Callable(), Callable(recorder, "record").bind("B"), Callable(), 0)
	screen.call("add_button", button_c, Callable(), Callable(recorder, "record").bind("C"), Callable(), 1)

	screen.call("set_active_group", 1)
	_assert(screen.get_active_group_index() == 1, "active group should be 1 after switch")
	_assert(screen.get_active_button_index() == 0, "switching group should select first button")
	_assert(recorder.items.size() >= 2 and recorder.items[-1] == "C", "group switch should select first button in group")

func _test_navigation_stays_in_group() -> void:
	var screen := Screen.new()
	var recorder := Recorder.new()

	var button_a := _make_button("A")
	var button_b := _make_button("B")
	var button_c := _make_button("C")
	var button_d := _make_button("D")

	screen.set_active(true)
	screen.call("add_button", button_a, Callable(), Callable(recorder, "record").bind("A"), Callable(), 0)
	screen.call("add_button", button_b, Callable(), Callable(recorder, "record").bind("B"), Callable(), 0)
	screen.call("add_button", button_c, Callable(), Callable(recorder, "record").bind("C"), Callable(), 1)
	screen.call("add_button", button_d, Callable(), Callable(recorder, "record").bind("D"), Callable(), 1)

	screen.call("set_active_group", 1)
	_assert(screen.get_active_button_index() == 0, "group 1 should start at first button")
	screen.navigate(1)
	_assert(screen.get_active_button_index() == 1, "navigate should move within active group")
	screen.navigate(1)
	_assert(screen.get_active_button_index() == 0, "navigate should wrap within active group")
