extends Node
var player_data_items : Array[String] = [
	"PROMISE",
	"PROMISE",
	"PROMISE",
	"PROMISE",
	"monster_candy",
	"spider_donut",
	"butts_pie"
];

var player_data = {
	hp = 20,
	hp_max = 20,
	def = 0,
	atk = 0,
	weapon = null,
	armor = null,
	items = player_data_items
}

signal player_hp_changed(hp: int, maximum: int)

func player_get_data(_name : String):
	return player_data[_name];

func player_get_item(_slot : int):
	if _slot < 0 or _slot >= player_data_items.size(): return null;
	return player_data_items[_slot]

func player_set_hp(value: int) -> void:
	player_data.hp = clampi(value, 0, int(player_data.hp_max))
	player_hp_changed.emit(player_data.hp, player_data.hp_max)

func player_heal(amount: int) -> void:
	player_set_hp(int(player_data.hp) + maxi(amount, 0))

func player_get_items():
	return player_data_items;

func player_get_item_count():
	return len(player_data_items);

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
	player_data_items.assign(player_data.items)
	player_data.items = player_data_items
	player_hp_changed.emit(player_data.hp, player_data.hp_max)

func toggle_fullscreen():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
