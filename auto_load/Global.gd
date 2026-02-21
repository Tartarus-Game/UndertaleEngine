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

var player_data_items: Array[Item] = []

func _ready() -> void:
	# 初始测试：往玩家包里塞进实体 Item 对象
	# 这些 ID 会被对应的 ItemManager 解析为注册时的名称与回调
	var initial_item_ids = ["PIE", "SNOWPIECE", "SNOWPIECE"]
	for id in initial_item_ids:
		var item = ItemManager.item_get(id)
		if item:
			player_data_items.append(item)
			
	if not InputMap.has_action("toggle_fullscreen"):
		InputMap.add_action("toggle_fullscreen")
		var event := InputEventKey.new()
		event.keycode = KEY_F4
		InputMap.action_add_event("toggle_fullscreen", event)

func player_get_data(key: String) -> Variant:
	return player_data.get(key)

func player_get_item(slot: int) -> Item:
	if slot < 0 or slot >= player_data_items.size():
		return null
	return player_data_items[slot]

func player_get_items() -> Array[Item]:
	return player_data_items

func player_get_item_count() -> int:
	return player_data_items.size()


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
