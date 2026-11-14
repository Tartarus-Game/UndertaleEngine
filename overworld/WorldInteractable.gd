class_name WorldInteractable extends OverworldTrigger

enum Kind { DIALOGUE, SAVE, SHOP, DOOR }
@export var kind: Kind = Kind.DIALOGUE
@export_multiline var message := "* Hello."
@export var options: Array[String] = []
@export var choice_flag := ""
@export var shop_stock: Array[String] = []
@export var shop_dialogue: Array[String] = []
@export_file("*.tscn") var target_scene := ""
@export var target_position := Vector2(320, 240)
func interact(actor: OverworldChar) -> void:
	if DialogueService.busy or EventService.running or ShopService.busy: return
	triggered.emit(actor)
	match kind:
		Kind.DIALOGUE:
			var steps: Array = []
			if options.is_empty(): steps.append({"type": "dialogue", "text": message})
			else: steps.append({"type": "choice", "text": message, "options": options, "flag": choice_flag})
			EventService.run(steps, actor)
		Kind.SAVE:
			_save()
		Kind.SHOP:
			ShopService.open_shop(shop_stock, shop_dialogue)
		Kind.DOOR:
			EventService.run([{"type": "warp", "scene": target_scene, "position": target_position}], actor)


func _save() -> void:
	var slot := Global.current_save_slot
	var options_list := [SettingsService.text("save.save"), SettingsService.text("save.load"), SettingsService.text("save.slot"), SettingsService.text("save.cancel")]
	var choice: int = await DialogueService.present(SettingsService.text("save.title") % (slot + 1), options_list)
	match choice:
		0:
			var saved := Global.storage_save("user://saves/", slot)
			await DialogueService.present(SettingsService.text("save.done") if saved else SettingsService.text("save.failed"))
		1:
			if Global.storage_has_save("user://saves/", slot):
				DialogueService.load_save_with_feedback("user://saves/", slot)
			else:
				await DialogueService.present(SettingsService.text("save.missing"))
		2:
			var selected: int = await DialogueService.present(SettingsService.text("save.choose"), ["1", "2", "3"])
			if selected >= 0:
				Global.current_save_slot = selected
				await _save()


func _draw() -> void:
	var colors := [Color.LIGHT_BLUE, Color.YELLOW, Color.LIGHT_GREEN, Color.ORANGE]
	draw_circle(Vector2.ZERO, 10.0, colors[kind])
	draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
