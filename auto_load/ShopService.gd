extends CanvasLayer

signal closed
var busy := false
var stock: Array[String] = []
var dialogue: Array[String] = []
var state := "main"
var selection := 0
var talk_index := 0
var notice := ""
var armed := false
var panel: Panel
var label: RichTextLabel
var actor: OverworldChar
var actor_was_enabled := false


func _ready() -> void:
	layer = 25
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
	font.fallbacks = [load("res://font/SIMSUNB.TTF")]
	label.add_theme_font_override("normal_font", font)
	panel.add_child(label)
	var hint := Label.new()
	hint.position = Vector2(25, 338)
	hint.text = "Z: OK   X: Back   PgUp/PgDn: Text"
	hint.add_theme_font_override("font", font)
	hint.add_theme_font_size_override("font_size", 15)
	panel.add_child(hint)


func open_shop(items: Array, lines: Array = []) -> void:
	if busy: return
	stock.clear()
	for id in items:
		if ItemManager.item_has(str(id)): stock.append(str(id))
	dialogue.clear()
	for line in lines: dialogue.append(str(line))
	var players := get_tree().get_nodes_in_group("overworld_player")
	actor = players[0] if not players.is_empty() else null
	if is_instance_valid(actor):
		actor_was_enabled = actor.movement_enabled
		actor.movement_enabled = false
	busy = true
	armed = false
	state = "main"
	selection = 0
	notice = ""
	visible = true
	_refresh()


func buy(id: String) -> bool:
	var item := ItemManager.item_get(id)
	if item == null or id not in stock or int(Global.player_data.gold) < item.price:
		return false
	if not Global.add_item(id): return false
	Global.player_data.gold -= item.price
	Global.player_stats_changed.emit()
	return true


func sell(slot: int) -> bool:
	var id = Global.player_get_item(slot)
	if id == null: return false
	var item := ItemManager.item_get(id)
	if item == null or not item.droppable: return false
	Global.player_data.gold += int(item.price / 2)
	Global.remove_item(slot)
	return true


func _process(_delta: float) -> void:
	if busy and not Input.is_action_pressed("ui_accept") and not Input.is_action_pressed("ui_cancel"): armed = true


func _unhandled_input(event: InputEvent) -> void:
	if not busy or not armed: return
	if event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		label.get_v_scroll_bar().value += -100.0 if event.keycode == KEY_PAGEUP else 100.0
		get_viewport().set_input_as_handled()
		return
	var count := 4 if state == "main" else (stock.size() if state == "buy" else Global.player_get_item_count())
	if event.is_action_pressed("ui_down") and count > 0: selection = posmod(selection + 1, count)
	elif event.is_action_pressed("ui_up") and count > 0: selection = posmod(selection - 1, count)
	elif event.is_action_pressed("ui_cancel"):
		if state == "main": _close()
		else: state = "main"; selection = 0; notice = ""
	elif event.is_action_pressed("ui_accept"):
		if state == "main":
			match selection:
				0: state = "buy"; selection = 0
				1: state = "sell"; selection = 0
				2:
					if not dialogue.is_empty():
						notice = dialogue[talk_index % dialogue.size()]
						talk_index += 1
				3: _close()
		elif state == "buy" and not stock.is_empty():
			notice = SettingsService.text("shop.purchased") if buy(stock[selection]) else SettingsService.text("shop.no_buy")
		elif state == "sell" and Global.player_get_item_count() > 0:
			notice = SettingsService.text("shop.sold") if sell(selection) else SettingsService.text("shop.no_sell")
			selection = mini(selection, maxi(0, Global.player_get_item_count() - 1))
	else: return
	_refresh()
	get_viewport().set_input_as_handled()


func _refresh() -> void:
	if not is_instance_valid(label): return
	var lines: Array[String] = []
	if state == "main":
		for key in ["shop.buy", "shop.sell", "shop.talk", "shop.leave"]: lines.append(SettingsService.text(key))
	elif state == "buy":
		for id in stock:
			var item := ItemManager.item_get(id)
			lines.append("%s  %d G" % [item.get_display_name(), item.price])
	else:
		for id in Global.player_get_items():
			var item := ItemManager.item_get(id)
			lines.append("%s  %d G" % [item.get_display_name(), int(item.price / 2)] if item else id)
	var output := "SHOP       %d G\n\n" % int(Global.player_data.gold)
	for i in range(lines.size()): output += ("> " if i == selection else "  ") + lines[i] + "\n"
	if not notice.is_empty(): output += "\n" + notice
	label.text = output


func _close() -> void:
	busy = false
	visible = false
	if is_instance_valid(actor): actor.movement_enabled = actor_was_enabled
	actor = null
	closed.emit()
