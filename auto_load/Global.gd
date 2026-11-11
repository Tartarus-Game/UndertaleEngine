extends Node

signal player_hp_changed(hp: int, maximum: int)
signal player_stats_changed
signal flag_changed(key: String, value: Variant)

const EXP_LEVELS := [0, 10, 30, 70, 120, 200, 300, 500, 800, 1200, 1700, 2500, 3500, 5000, 7000, 10000, 15000, 25000, 50000, 99999]
const INVENTORY_CAPACITY := 8

var player_data_items: Array[String] = [
	"PROMISE", "PROMISE", "PROMISE", "PROMISE", "monster_candy", "spider_donut", "butts_pie"
]
var player_data := {
	"name": "PLAYER", "hp": 20, "hp_max": 20, "def": 0, "atk": 20,
	"weapon": "", "armor": "", "exp": 0, "gold": 0, "lv": 1,
	"kr": 0.0, "kr_enabled": false, "items": player_data_items
}
var world_state := {"flags": {}, "scene": "", "position": Vector2.ZERO}
var current_save_slot := 0


func _ready() -> void:
	if not InputMap.has_action("toggle_fullscreen"):
		InputMap.add_action("toggle_fullscreen")
		var event := InputEventKey.new()
		event.keycode = KEY_F4
		InputMap.action_add_event("toggle_fullscreen", event)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()


func player_get_data(key: String):
	return player_data[key]


func player_get_item(slot: int):
	return player_data_items[slot] if slot >= 0 and slot < player_data_items.size() else null


func player_get_items() -> Array[String]:
	return player_data_items


func player_get_item_count() -> int:
	return player_data_items.size()


func add_item(id: String) -> bool:
	if not ItemManager.item_has(id) or player_data_items.size() >= INVENTORY_CAPACITY:
		return false
	player_data_items.append(id)
	player_stats_changed.emit()
	return true


func player_set_hp(value: int) -> void:
	player_data.hp = clampi(value, 0, int(player_data.hp_max))
	player_hp_changed.emit(player_data.hp, player_data.hp_max)


func player_heal(amount: int) -> void:
	player_set_hp(int(player_data.hp) + maxi(amount, 0))


func player_get_attack() -> int:
	var item := ItemManager.item_get(str(player_data.weapon))
	return int(player_data.atk) + (item.attack_bonus if item else 0)


func player_get_defense() -> int:
	var item := ItemManager.item_get(str(player_data.armor))
	return int(player_data.def) + (item.defense_bonus if item else 0)


func equip_item(id: String) -> bool:
	var item := ItemManager.item_get(id)
	if item == null or item.equipment_slot not in ["weapon", "armor"] or id not in player_data_items:
		return false
	player_data[item.equipment_slot] = id
	player_stats_changed.emit()
	return true


func remove_item(slot: int) -> bool:
	if slot < 0 or slot >= player_data_items.size():
		return false
	var id := player_data_items[slot]
	player_data_items.remove_at(slot)
	if id not in player_data_items:
		if player_data.weapon == id: player_data.weapon = ""
		if player_data.armor == id: player_data.armor = ""
	player_stats_changed.emit()
	return true


func award_rewards(exp_amount: int, gold_amount: int) -> bool:
	player_data.exp = maxi(0, int(player_data.exp) + exp_amount)
	player_data.gold = maxi(0, int(player_data.gold) + gold_amount)
	var old_lv := int(player_data.lv)
	var lv := 1
	for i in range(EXP_LEVELS.size()):
		if int(player_data.exp) >= EXP_LEVELS[i]:
			lv = i + 1
	player_data.lv = lv
	if lv > old_lv:
		player_data.hp_max = 20 + (lv - 1) * 4
		player_set_hp(int(player_data.hp_max))
	player_stats_changed.emit()
	return lv > old_lv


func set_flag(key: String, value: Variant) -> void:
	world_state.flags[key] = value
	flag_changed.emit(key, value)


func get_flag(key: String, default: Variant = null) -> Variant:
	return world_state.flags.get(key, default)


func capture_world() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene is Battle:
		return
	if not scene.scene_file_path.is_empty():
		world_state.scene = scene.scene_file_path
	var players := get_tree().get_nodes_in_group("overworld_player")
	if not players.is_empty():
		world_state.position = players[0].global_position


func storage_save(path: String, slot: int) -> bool:
	capture_world()
	DirAccess.make_dir_recursive_absolute(path)
	var file := FileAccess.open(path.path_join("file" + str(slot)), FileAccess.WRITE)
	if file == null:
		return false
	file.store_var({"version": 1, "player": player_data, "world": world_state})
	current_save_slot = slot
	return true


func storage_load(path: String, slot: int) -> bool:
	var file := FileAccess.open(path.path_join("file" + str(slot)), FileAccess.READ)
	if file == null:
		return false
	var saved: Variant = file.get_var()
	if not saved is Dictionary:
		return false
	# The earlier prototype wrote player_data directly.
	var saved_player: Dictionary = saved.get("player", saved)
	for key in saved_player:
		player_data[key] = saved_player[key]
	player_data_items.assign(player_data.get("items", []))
	player_data.items = player_data_items
	if saved.has("world"):
		world_state = saved.world
	current_save_slot = slot
	player_hp_changed.emit(int(player_data.hp), int(player_data.hp_max))
	player_stats_changed.emit()
	return true


func restore_world(path: String, slot: int) -> bool:
	if not storage_load(path, slot):
		return false
	var scene_path := str(world_state.get("scene", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return false
	return await OverworldManager.change_room(scene_path, world_state.position)


func toggle_fullscreen() -> void:
	SettingsService.set_fullscreen(DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN)
