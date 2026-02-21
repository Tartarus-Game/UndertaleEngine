extends Node

# ——— 玩家数据 ———
var player_data: Dictionary = {
	hp = 0,
	hp_max = 0,
	def = 0,
	atk = 0,
	weapon = null,
	armor = null,
}

var player_data_items: Array[String] = [
	"PROMISE",
	"PROMISE",
	"PROMISE",
	"PROMISE"
]

func player_get_data(key: String) -> Variant:
	return player_data.get(key)

## 注意：has() 检测的是值而非索引，应改为索引范围检测
func player_get_item(slot: int) -> String:
	if slot < 0 or slot >= player_data_items.size():
		return ""
	return player_data_items[slot]

func player_get_items() -> Array[String]:
	return player_data_items

func player_get_item_count() -> int:
	return player_data_items.size()

# ——— 输入/窗口 ———

func _ready() -> void:
	if not InputMap.has_action("toggle_fullscreen"):
		InputMap.add_action("toggle_fullscreen")
		var event := InputEventKey.new()
		event.keycode = KEY_F4
		InputMap.action_add_event("toggle_fullscreen", event)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()

# ——— 存储 ———

func storage_save(path: String, slot: int) -> void:
	DirAccess.make_dir_recursive_absolute(path)
	var file := FileAccess.open(path + "file" + str(slot), FileAccess.WRITE)
	if file:
		file.store_var(player_data)

func storage_load(path: String, slot: int) -> void:
	DirAccess.make_dir_recursive_absolute(path)
	var file := FileAccess.open(path + "file" + str(slot), FileAccess.READ)
	if not file:
		return
	player_data = file.get_var()

# ——— 全屏 ———

func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
