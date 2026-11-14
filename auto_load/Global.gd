extends Node

signal player_hp_changed(hp: int, maximum: int)
signal player_stats_changed
signal flag_changed(key: String, value: Variant)
signal save_recovered(slot: int)

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
var last_save_recovered := false


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
	if DirAccess.make_dir_recursive_absolute(path) != OK: return false
	var primary := path.path_join("file" + str(slot))
	var temporary := primary + ".tmp"
	var backup := primary + ".bak"
	var invalid := primary + ".invalid"
	# A backup from a newer version must not be shadowed now or replaced on
	# the next save, even if the primary is missing or otherwise readable.
	if _read_save_file(backup).has("unsupported_version"): return false
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var({"version": 1, "player": player_data, "world": world_state})
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return false
	var previous_path := ""
	if FileAccess.file_exists(primary):
		# Never replace a valid backup with a corrupt primary.
		var existing := _read_save_file(primary)
		if existing.has("unsupported_version"):
			DirAccess.remove_absolute(temporary)
			return false
		# A structurally valid world can still point to a removed room. Keep
		# the recoverable backup rather than replacing it with that primary.
		var usable := not existing.is_empty()
		if usable and existing.get("has_world", false):
			usable = _saved_room_exists(existing)
		previous_path = backup if usable else invalid
		if FileAccess.file_exists(previous_path) and DirAccess.remove_absolute(previous_path) != OK:
			DirAccess.remove_absolute(temporary)
			return false
		if DirAccess.rename_absolute(primary, previous_path) != OK:
			DirAccess.remove_absolute(temporary)
			return false
	if DirAccess.rename_absolute(temporary, primary) != OK:
		if not previous_path.is_empty(): DirAccess.rename_absolute(previous_path, primary)
		DirAccess.remove_absolute(temporary)
		return false
	current_save_slot = slot
	last_save_recovered = false
	return true


func storage_has_save(path: String, slot: int) -> bool:
	var primary := path.path_join("file" + str(slot))
	return FileAccess.file_exists(primary) or FileAccess.file_exists(primary + ".bak")


func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() < 4: return {}
	var record_size := file.get_32()
	if record_size < 4 or record_size > file.get_length() - 4: return {}
	file.seek(0)
	var saved: Variant = file.get_var()
	if not saved is Dictionary:
		return {}
	if saved.has("version") and saved.version != 1:
		return {"unsupported_version": saved.version}
	if saved.has("version") and not saved.has("player"): return {}
	# The earlier prototype wrote player_data directly.
	var saved_player: Variant = saved.get("player", saved)
	if not saved_player is Dictionary:
		return {}
	var loaded_player := player_data.duplicate(true)
	for key in saved_player:
		loaded_player[key] = saved_player[key]
	for key in ["hp", "hp_max", "atk", "def", "exp", "gold", "lv", "kr"]:
		if typeof(loaded_player.get(key)) not in [TYPE_INT, TYPE_FLOAT]: return {}
	for key in ["name", "weapon", "armor"]:
		if not loaded_player.get(key) is String: return {}
	if not loaded_player.get("kr_enabled") is bool or not loaded_player.get("items") is Array:
		return {}
	for item in loaded_player.items:
		if not item is String: return {}
	var loaded_world := world_state.duplicate(true)
	if saved.has("world"):
		if not saved.world is Dictionary: return {}
		loaded_world = {"flags": {}, "scene": "", "position": Vector2.ZERO}
		loaded_world.merge(saved.world, true)
	if not loaded_world.get("flags") is Dictionary or not loaded_world.get("scene") is String or not loaded_world.get("position") is Vector2:
		return {}
	return {"player": loaded_player, "world": loaded_world, "has_world": saved.has("world")}


func _read_save(path: String, slot: int) -> Dictionary:
	var primary := path.path_join("file" + str(slot))
	var saved := _read_save_file(primary)
	if saved.has("unsupported_version"): return {}
	if not saved.is_empty(): return saved
	saved = _read_save_file(primary + ".bak")
	if saved.has("unsupported_version"): return {}
	if not saved.is_empty(): saved["recovered"] = true
	return saved


func _record_recovery(saved: Dictionary, slot: int) -> void:
	last_save_recovered = bool(saved.get("recovered", false))
	if last_save_recovered: save_recovered.emit(slot)


func _apply_save(saved: Dictionary, slot: int) -> void:
	player_data.clear()
	player_data.merge(saved.player, true)
	player_data_items.assign(player_data.get("items", []))
	player_data.items = player_data_items
	world_state = saved.world
	current_save_slot = slot
	player_hp_changed.emit(int(player_data.hp), int(player_data.hp_max))
	player_stats_changed.emit()


func storage_load(path: String, slot: int) -> bool:
	var saved := _read_save(path, slot)
	if saved.is_empty(): return false
	_apply_save(saved, slot)
	_record_recovery(saved, slot)
	return true


func restore_world(path: String, slot: int) -> bool:
	var saved := _read_save(path, slot)
	if saved.is_empty(): return false
	if not _saved_room_exists(saved):
		if saved.get("recovered", false): return false
		saved = _read_save_file(path.path_join("file" + str(slot) + ".bak"))
		if saved.is_empty() or saved.has("unsupported_version") or not _saved_room_exists(saved): return false
		saved["recovered"] = true
	var scene_path: String = saved.world.scene
	var previous := {"player": player_data.duplicate(true), "world": world_state.duplicate(true)}
	var previous_slot := current_save_slot
	_apply_save(saved, slot)
	if await OverworldManager.change_room(scene_path, world_state.position):
		_record_recovery(saved, slot)
		return true
	_apply_save(previous, previous_slot)
	return false


func _saved_room_exists(saved: Dictionary) -> bool:
	var scene_path: String = saved.world.scene
	return not scene_path.is_empty() and ResourceLoader.exists(scene_path) and load(scene_path) is PackedScene


func toggle_fullscreen() -> void:
	SettingsService.set_fullscreen(DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN)
