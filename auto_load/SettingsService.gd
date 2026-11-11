extends Node

signal settings_changed
var language := "en"
var window_scale := 1.0
var bindings := {}
var translations := {
	"en": {"menu.items": "ITEMS", "menu.stats": "STATS", "menu.settings": "SETTINGS", "menu.phone": "PHONE", "menu.close": "C / X: Close", "shop.buy": "BUY", "shop.sell": "SELL", "shop.talk": "TALK", "shop.leave": "LEAVE", "save.question": "Save your progress?", "save.done": "Progress saved.", "yes": "Yes", "no": "No"},
	"zh_CN": {"menu.items": "物品", "menu.stats": "状态", "menu.settings": "设置", "menu.phone": "电话", "menu.close": "C / X：关闭", "shop.buy": "购买", "shop.sell": "出售", "shop.talk": "交谈", "shop.leave": "离开", "save.question": "要保存进度吗？", "save.done": "进度已保存。", "yes": "是", "no": "否"}
}


func _ready() -> void:
	translations.en.merge({
		"battle.choose": "* Choose an action.", "battle.spare": "Spare", "battle.flee": "Flee",
		"item.use": "Use", "item.info": "Info", "item.drop": "Drop",
		"battle.won": "* You won!", "battle.fled": "* You fled.", "battle.defeated": "* You were defeated.\n* Press Z to return.",
		"battle.reward": "* %d EXP and %d GOLD.\n* Press Z to return.",
		"battle.level_up": "* Your LOVE increased.", "battle.damage": "* %s took %d damage.",
		"battle.no_escape": "* You cannot escape!", "battle.failed_escape": "* You couldn't escape!", "battle.ran": "* You ran away.",
		"battle.no_spare": "* No enemy is ready to be spared.", "battle.spared": "* You spared %d enemy(s).",
		"shop.purchased": "Purchased.", "shop.no_buy": "Cannot buy.", "shop.sold": "Sold.", "shop.no_sell": "Cannot sell.",
		"save.title": "* Save slot %d", "save.save": "Save", "save.load": "Load", "save.slot": "Slot", "save.cancel": "Cancel",
		"save.choose": "* Choose a save slot.", "save.missing": "* No save exists in this slot.", "save.failed": "* Could not save.",
		"gameover.text": "* GAME OVER\n* Stay determined.", "gameover.load": "Load save", "gameover.continue": "Continue"
	}, true)
	translations.zh_CN.merge({
		"battle.choose": "* 选择一个行动。", "battle.spare": "饶恕", "battle.flee": "逃跑",
		"item.use": "使用", "item.info": "信息", "item.drop": "丢弃",
		"battle.won": "* 你赢了！", "battle.fled": "* 你逃走了。", "battle.defeated": "* 你被打败了。\n* 按 Z 继续。",
		"battle.reward": "* 获得 %d EXP 和 %d GOLD。\n* 按 Z 继续。",
		"battle.level_up": "* 你的 LOVE 增加了。", "battle.damage": "* %s 受到了 %d 点伤害。",
		"battle.no_escape": "* 你无法逃跑！", "battle.failed_escape": "* 你没能逃走！", "battle.ran": "* 你逃走了。",
		"battle.no_spare": "* 没有敌人愿意被饶恕。", "battle.spared": "* 你饶恕了 %d 个敌人。",
		"shop.purchased": "购买成功。", "shop.no_buy": "无法购买。", "shop.sold": "出售成功。", "shop.no_sell": "无法出售。",
		"save.title": "* 存档槽 %d", "save.save": "保存", "save.load": "读取", "save.slot": "槽位", "save.cancel": "取消",
		"save.choose": "* 选择存档槽。", "save.missing": "* 这个槽位还没有存档。", "save.failed": "* 保存失败。",
		"gameover.text": "* 游戏结束\n* 保持你的决心。", "gameover.load": "读取存档", "gameover.continue": "继续"
	}, true)
	if not InputMap.has_action("ui_menu"):
		InputMap.add_action("ui_menu")
	# Godot may already define ui_menu, but its default does not include C.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_C
	if not InputMap.action_has_event("ui_menu", key):
		InputMap.action_add_event("ui_menu", key)
	_ensure_joy("ui_accept", JOY_BUTTON_A)
	_ensure_joy("ui_cancel", JOY_BUTTON_B)
	_ensure_joy("ui_menu", JOY_BUTTON_X)
	_ensure_joy("ui_up", JOY_BUTTON_DPAD_UP)
	_ensure_joy("ui_down", JOY_BUTTON_DPAD_DOWN)
	_ensure_joy("ui_left", JOY_BUTTON_DPAD_LEFT)
	_ensure_joy("ui_right", JOY_BUTTON_DPAD_RIGHT)
	load_settings()


func text(key: String) -> String:
	return str(translations.get(language, translations.en).get(key, translations.en.get(key, key)))


func set_language(value: String) -> void:
	if translations.has(value):
		language = value
		TranslationServer.set_locale(value)
		save_settings()
		settings_changed.emit()


func set_window_scale(value: float) -> void:
	window_scale = clampf(value, 1.0, 3.0)
	DisplayServer.window_set_size(Vector2i(640, 480) * window_scale)
	save_settings()
	settings_changed.emit()


func bind_key(action: String, physical_keycode: int) -> void:
	if not InputMap.has_action(action): return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey: InputMap.action_erase_event(action, event)
	var key := InputEventKey.new()
	key.physical_keycode = physical_keycode
	InputMap.action_add_event(action, key)
	bindings[action] = physical_keycode
	save_settings()
	settings_changed.emit()


func _ensure_joy(action: String, button: JoyButton) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button: return
	var joy := InputEventJoypadButton.new()
	joy.device = -1
	joy.button_index = button
	InputMap.action_add_event(action, joy)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "language", language)
	config.set_value("general", "window_scale", window_scale)
	config.set_value("input", "bindings", bindings)
	config.save("user://settings.cfg")


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") != OK: return
	language = str(config.get_value("general", "language", "en"))
	window_scale = float(config.get_value("general", "window_scale", 1.0))
	var saved: Dictionary = config.get_value("input", "bindings", {})
	for action in saved: bind_key(str(action), int(saved[action]))
	TranslationServer.set_locale(language)
