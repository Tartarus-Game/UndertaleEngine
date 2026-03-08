extends Node
var player_data = {
	hp = 0,
	hp_max = 0,
	def = 0,
	atk = 0,
	weapon = null,
	armor = null,
	items = player_data_items
}

const BATTLE_SOUL_COLLISION_LAYER := 5
const BATTLE_BOX_COLLISION_LAYER := 2

var player_data_items = [];

func player_get_data(_name : String):
	return player_data[_name];

func player_item_add(id : String):
	player_data_items.append(id);

func player_get_item(_slot : int):
	if(!player_data_items.has(_slot)): return;
	return player_data_items[_slot]

func _ready() -> void:
	if not InputMap.has_action("toggle_fullscreen"):
		InputMap.add_action("toggle_fullscreen")
		var event = InputEventKey.new()
		event.keycode = KEY_F4
		InputMap.action_add_event("toggle_fullscreen", event)

func _input(event):
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()

func storage_save(path: String, slot: int):
	DirAccess.make_dir_recursive_absolute(path);
	var file = FileAccess.open(path + "file" + str(slot), FileAccess.WRITE);
	file.store_var(player_data);

func storage_load(path : String, slot : int):
	DirAccess.make_dir_recursive_absolute(path);
	var file = FileAccess.open(path + "file" + str(slot), FileAccess.READ);
	if(!file):return;
	player_data = file.get_var();

func toggle_fullscreen():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
