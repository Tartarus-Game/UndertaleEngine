extends CanvasLayer

var enabled := false
var invincible := false
var label: Label
var rooms: Array[String] = ["res://overworld/test_level/test.tscn", "res://overworld/test_level/side_room.tscn"]


func register_room(path: String) -> void:
	if path not in rooms: rooms.append(path)


func _ready() -> void:
	layer = 100
	label = Label.new()
	label.position = Vector2(8, 8)
	label.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	label.add_theme_stylebox_override("normal", style)
	add_child(label)
	label.visible = false


func _process(_delta: float) -> void:
	if not enabled: return
	var current := get_tree().current_scene
	var detail := "Overworld"
	if current is Battle:
		detail = "Battle turn %d  soul=%s  waves=%d" % [current.turn_number, current.soul.mode, current.active_waves.size()]
	label.text = "DEBUG  F3 hide  H invincible: %s\n%s\nHP %d/%d  GOLD %d  flags %d\n1 red 2 blue 3 green 4 yellow 5 aqua 6 orange\nF6 end wave  F7 room  F8 battle  F9 shop\nPageUp/PageDown HP" % [invincible, detail, Global.player_data.hp, Global.player_data.hp_max, Global.player_data.gold, Global.world_state.flags.size()]


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F3:
		enabled = not enabled
		label.visible = enabled
		get_viewport().set_input_as_handled()
		return
	if not enabled: return
	var battle := get_tree().current_scene as Battle
	match event.keycode:
		KEY_H: invincible = not invincible
		KEY_PAGEUP: Global.player_heal(5)
		KEY_PAGEDOWN: Global.player_set_hp(maxi(1, int(Global.player_data.hp) - 5))
		KEY_F6:
			if battle: battle.end_enemy_turn()
		KEY_F7:
			if battle == null and not rooms.is_empty() and not DialogueService.busy and not ShopService.busy and not WorldMenu.busy and not EventService.running:
				var index := posmod(rooms.find(get_tree().current_scene.scene_file_path) + 1, rooms.size())
				OverworldManager.change_room(rooms[index])
		KEY_F8:
			if battle == null and not DialogueService.busy and not ShopService.busy and not WorldMenu.busy:
				EncounterManager.encounter(-1, false)
		KEY_F9:
			if battle == null and not DialogueService.busy: ShopService.open_shop(["monster_candy", "toy_knife", "ribbon"], ["* Debug shop."])
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			if battle: battle.soul.set_mode(["red", "blue", "green", "yellow", "aqua", "orange"][event.keycode - KEY_1])
		_: return
	get_viewport().set_input_as_handled()
