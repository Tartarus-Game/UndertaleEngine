extends CanvasLayer

const REMAP_ACTIONS := ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_cancel", "ui_menu"]

var busy := false
var armed := false
var state := "root"
var selected := 0
var command := 0
var notice := ""
var capture_action := ""
var panel: Panel
var label: RichTextLabel
var hint: Label
var actor: OverworldChar
var was_enabled := false
var phone_entries: Array[Dictionary] = []


func _ready() -> void:
	layer = 24
	visible = false
	panel = Panel.new()
	panel.position = Vector2(55, 55)
	panel.size = Vector2(530, 370)
	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.border_color = Color.WHITE
	style.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	label = RichTextLabel.new()
	label.position = Vector2(25, 20)
	label.size = Vector2(480, 300)
	label.fit_content = false
	label.scroll_active = true
	label.bbcode_enabled = true
	label.add_theme_font_size_override("normal_font_size", 18)
	var font := FontVariation.new()
	font.base_font = load("res://font/DTM-momo.otf")
	font.fallbacks = [load("res://font/NotoSansSC.ttf"), load("res://font/SIMSUNB.TTF")]
	label.add_theme_font_override("normal_font", font)
	panel.add_child(label)
	hint = Label.new()
	hint.position = Vector2(25, 338)
	hint.text = "Confirm / Cancel   PgUp/PgDn: Text"
	hint.add_theme_font_override("font", font)
	hint.add_theme_font_size_override("font_size", 15)
	panel.add_child(hint)


func register_phone(title: String, message: String) -> void:
	for entry in phone_entries:
		if entry.title == title:
			entry.message = message
			return
	phone_entries.append({"title": title, "message": message})


func open_menu() -> void:
	var players := get_tree().get_nodes_in_group("overworld_player")
	if players.is_empty() or DialogueService.busy or ShopService.busy or EventService.running: return
	actor = players[0]
	was_enabled = actor.movement_enabled
	actor.movement_enabled = false
	busy = true
	armed = false
	state = "root"
	selected = 0
	command = 0
	notice = ""
	visible = true
	_refresh()


func _process(_delta: float) -> void:
	if busy and not Input.is_action_pressed("ui_accept") and not Input.is_action_pressed("ui_cancel"): armed = true


func _unhandled_input(event: InputEvent) -> void:
	if not busy:
		if event.is_action_pressed("ui_menu"):
			open_menu()
			if busy: get_viewport().set_input_as_handled()
		return
	if not capture_action.is_empty():
		if event is InputEventKey and event.pressed and not event.echo:
			var key_event := event as InputEventKey
			SettingsService.bind_key(capture_action, key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode)
			capture_action = ""
			notice = SettingsService.text("settings.saved")
			_refresh()
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and event.pressed:
			var joy_event := event as InputEventJoypadButton
			SettingsService.bind_joy(capture_action, joy_event.device, joy_event.button_index)
			capture_action = ""
			notice = SettingsService.text("settings.saved")
			_refresh()
			get_viewport().set_input_as_handled()
		return
	if not armed: return
	if event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		label.get_v_scroll_bar().value += -100.0 if event.keycode == KEY_PAGEUP else 100.0
		get_viewport().set_input_as_handled()
		return
	var count := _entry_count()
	if event.is_action_pressed("ui_down") and count > 0: selected = posmod(selected + 1, count)
	elif event.is_action_pressed("ui_up") and count > 0: selected = posmod(selected - 1, count)
	elif event.is_action_pressed("ui_left") and state == "items": command = posmod(command - 1, 3)
	elif event.is_action_pressed("ui_right") and state == "items": command = posmod(command + 1, 3)
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_menu"):
		if state == "root": _close()
		else: state = "root"; selected = 0; notice = ""
	elif event.is_action_pressed("ui_accept"):
		_activate()
	else: return
	_refresh()
	get_viewport().set_input_as_handled()


func _entry_count() -> int:
	match state:
		"root": return 5
		"items": return Global.player_get_item_count()
		"phone": return phone_entries.size()
		"settings": return 11
	return 0


func _activate() -> void:
	if state == "root":
		match selected:
			0: state = "items"
			1: state = "stats"
			2: state = "phone"
			3: state = "settings"
			4: _close(); return
		selected = 0
		notice = ""
	elif state == "items" and Global.player_get_item_count() > 0:
		var item := ItemManager.item_get(Global.player_get_item(selected))
		if item == null: return
		item._slot = selected
		match command:
			0:
				notice = item.use()
				if item.consumable: Global.remove_item(selected)
			1: notice = item.info()
			2:
				notice = item.drop()
				if item.droppable: Global.remove_item(selected)
		selected = mini(selected, maxi(0, Global.player_get_item_count() - 1))
	elif state == "phone" and not phone_entries.is_empty():
		notice = str(phone_entries[selected].message)
	elif state == "settings":
		match selected:
			0: SettingsService.set_language("zh_CN" if SettingsService.language == "en" else "en")
			1: SettingsService.set_window_scale(1.0 if SettingsService.window_scale >= 3.0 else SettingsService.window_scale + 0.5)
			2: Global.toggle_fullscreen()
			3, 4, 5, 6, 7, 8, 9:
				capture_action = REMAP_ACTIONS[selected - 3]
				notice = SettingsService.text("settings.press")
			10: state = "root"; selected = 0


func _refresh() -> void:
	var entries: Array[String] = []
	match state:
		"root":
			for key in ["menu.items", "menu.stats", "menu.phone", "menu.settings", "menu.close"]: entries.append(SettingsService.text(key))
		"items":
			for id in Global.player_get_items():
				var item := ItemManager.item_get(id)
				entries.append(item.get_display_name() if item else id)
		"stats":
			var p := Global.player_data
			notice = "%s    LV %d\nHP %d/%d    ATK %d    DEF %d\nEXP %d    GOLD %d\nWeapon: %s\nArmor: %s" % [p.name, p.lv, p.hp, p.hp_max, Global.player_get_attack(), Global.player_get_defense(), p.exp, p.gold, p.weapon, p.armor]
		"phone":
			for phone in phone_entries: entries.append(str(phone.title))
		"settings":
			entries.assign([SettingsService.text("settings.language") + ": " + SettingsService.language, SettingsService.text("settings.scale") + ": %.1f" % SettingsService.window_scale, SettingsService.text("settings.fullscreen")])
			for action in REMAP_ACTIONS:
				entries.append(SettingsService.text("settings.bind") + " " + SettingsService.text("input." + str(action).trim_prefix("ui_")))
			entries.append(SettingsService.text("settings.back"))
	var output := SettingsService.text("menu.title" if state == "root" else "menu." + state) + "\n\n"
	for i in range(entries.size()): output += ("> " if i == selected else "  ") + entries[i] + "\n"
	if state == "items":
		output += "\n"
		var commands := [SettingsService.text("item.use"), SettingsService.text("item.info"), SettingsService.text("item.drop")]
		for i in range(commands.size()): output += ("> " if i == command else "  ") + commands[i] + "  "
		output += "\n"
	if not notice.is_empty(): output += "\n" + notice
	label.text = output
	hint.text = SettingsService.text("ui.hint")
	label.call_deferred("scroll_to_line", maxi(0, selected - 7) if state == "settings" else 0)


func _close() -> void:
	busy = false
	visible = false
	if is_instance_valid(actor): actor.movement_enabled = was_enabled
	actor = null
