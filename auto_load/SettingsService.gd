extends Node

signal settings_changed
var language := "en"
var window_scale := 1.0
var fullscreen := false
var bindings := {}
var joy_bindings := {}
var _loading := false
var settings_path := "user://settings.cfg"
var translations := {
	"en": {"menu.items": "ITEMS", "menu.stats": "STATS", "menu.settings": "SETTINGS", "menu.phone": "PHONE", "menu.close": "CLOSE", "shop.buy": "BUY", "shop.sell": "SELL", "shop.talk": "TALK", "shop.leave": "LEAVE", "save.question": "Save your progress?", "save.done": "Progress saved.", "yes": "Yes", "no": "No"},
	"zh_CN": {"menu.items": "物品", "menu.stats": "状态", "menu.settings": "设置", "menu.phone": "电话", "menu.close": "关闭", "shop.buy": "购买", "shop.sell": "出售", "shop.talk": "交谈", "shop.leave": "离开", "save.question": "要保存进度吗？", "save.done": "进度已保存。", "yes": "是", "no": "否"}
}


func _ready() -> void:
	translations.en.merge({
		"battle.choose": "* Choose an action.", "battle.spare": "Spare", "battle.flee": "Flee",
		"item.use": "Use", "item.info": "Info", "item.drop": "Drop",
		"battle.won": "* You won!", "battle.fled": "* You fled.", "battle.defeated": "* You were defeated.\n* Press confirm to return.",
		"battle.reward": "* %d EXP and %d GOLD.\n* Press confirm to return.",
		"battle.level_up": "* Your LOVE increased.", "battle.damage": "* %s took %d damage.",
		"battle.no_escape": "* You cannot escape!", "battle.failed_escape": "* You couldn't escape!", "battle.ran": "* You ran away.",
		"battle.no_spare": "* No enemy is ready to be spared.", "battle.spared": "* You spared %d enemy(s).",
		"shop.purchased": "Purchased.", "shop.no_buy": "Cannot buy.", "shop.sold": "Sold.", "shop.no_sell": "Cannot sell.",
		"save.title": "* Save slot %d", "save.save": "Save", "save.load": "Load", "save.slot": "Slot", "save.cancel": "Cancel",
		"save.choose": "* Choose a save slot.", "save.missing": "* No save exists in this slot.", "save.failed": "* Could not save.", "save.load_failed": "* Could not load this save.",
		"gameover.text": "* GAME OVER\n* Stay determined.", "gameover.load": "Load save", "gameover.continue": "Continue",
		"menu.title": "MENU", "ui.hint": "Confirm / Cancel   PgUp/PgDn: Text", "shop.title": "SHOP",
		"settings.language": "Language", "settings.scale": "Window scale", "settings.fullscreen": "Toggle fullscreen",
		"settings.bind": "Bind", "settings.back": "Back", "settings.saved": "Binding saved.", "settings.press": "Press a key or gamepad button.",
		"input.up": "up", "input.down": "down", "input.left": "left", "input.right": "right", "input.accept": "confirm", "input.cancel": "cancel", "input.menu": "menu"
	}, true)
	translations.zh_CN.merge({
		"battle.choose": "* 选择一个行动。", "battle.spare": "饶恕", "battle.flee": "逃跑",
		"item.use": "使用", "item.info": "信息", "item.drop": "丢弃",
		"battle.won": "* 你赢了！", "battle.fled": "* 你逃走了。", "battle.defeated": "* 你被打败了。\n* 按确认键继续。",
		"battle.reward": "* 获得 %d EXP 和 %d GOLD。\n* 按确认键继续。",
		"battle.level_up": "* 你的 LOVE 增加了。", "battle.damage": "* %s 受到了 %d 点伤害。",
		"battle.no_escape": "* 你无法逃跑！", "battle.failed_escape": "* 你没能逃走！", "battle.ran": "* 你逃走了。",
		"battle.no_spare": "* 没有敌人愿意被饶恕。", "battle.spared": "* 你饶恕了 %d 个敌人。",
		"shop.purchased": "购买成功。", "shop.no_buy": "无法购买。", "shop.sold": "出售成功。", "shop.no_sell": "无法出售。",
		"save.title": "* 存档槽 %d", "save.save": "保存", "save.load": "读取", "save.slot": "槽位", "save.cancel": "取消",
		"save.choose": "* 选择存档槽。", "save.missing": "* 这个槽位还没有存档。", "save.failed": "* 保存失败。", "save.load_failed": "* 读取存档失败。",
		"gameover.text": "* 游戏结束\n* 保持你的决心。", "gameover.load": "读取存档", "gameover.continue": "继续",
		"menu.title": "菜单", "ui.hint": "确认 / 返回   PgUp/PgDn：翻页", "shop.title": "商店",
		"settings.language": "语言", "settings.scale": "窗口缩放", "settings.fullscreen": "切换全屏",
		"settings.bind": "绑定", "settings.back": "返回", "settings.saved": "按键已保存。", "settings.press": "请按下键盘或手柄按键。",
		"input.up": "上", "input.down": "下", "input.left": "左", "input.right": "右", "input.accept": "确认", "input.cancel": "取消", "input.menu": "菜单"
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
		if not _loading: save_settings()
		settings_changed.emit()


func set_window_scale(value: float) -> void:
	window_scale = clampf(value, 1.0, 3.0)
	DisplayServer.window_set_size(Vector2i(640, 480) * window_scale)
	if not _loading: save_settings()
	settings_changed.emit()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
	if not _loading: save_settings()
	settings_changed.emit()


func bind_key(action: String, physical_keycode: int) -> void:
	if not InputMap.has_action(action): return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey: InputMap.action_erase_event(action, event)
	var key := InputEventKey.new()
	key.physical_keycode = physical_keycode
	InputMap.action_add_event(action, key)
	bindings[action] = physical_keycode
	if not _loading: save_settings()
	settings_changed.emit()


func bind_joy(action: String, device: int, button: JoyButton) -> void:
	if not InputMap.has_action(action): return
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton: InputMap.action_erase_event(action, event)
	var joy := InputEventJoypadButton.new()
	joy.device = device
	joy.button_index = button
	InputMap.action_add_event(action, joy)
	joy_bindings[action] = {"device": device, "button": int(button)}
	if not _loading: save_settings()
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
	config.set_value("general", "fullscreen", fullscreen)
	config.set_value("input", "bindings", bindings)
	config.set_value("input", "joy_bindings", joy_bindings)
	config.save(settings_path)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK: return
	_loading = true
	language = str(config.get_value("general", "language", "en"))
	window_scale = float(config.get_value("general", "window_scale", 1.0))
	var saved: Dictionary = config.get_value("input", "bindings", {})
	for action in saved: bind_key(str(action), int(saved[action]))
	var saved_joy: Dictionary = config.get_value("input", "joy_bindings", {})
	for action in saved_joy:
		var binding: Dictionary = saved_joy[action]
		bind_joy(str(action), int(binding.device), int(binding.button))
	DisplayServer.window_set_size(Vector2i(640, 480) * window_scale)
	set_fullscreen(bool(config.get_value("general", "fullscreen", false)))
	TranslationServer.set_locale(language)
	_loading = false
