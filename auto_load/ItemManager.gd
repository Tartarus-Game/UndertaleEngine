extends Node

var items: Dictionary = {}

func item_has(id: String) -> bool:
	return items.has(id)

func register(id: String, item_name: String, _callable: Callable = Callable()) -> void:
	var item = Item.new(id, item_name, _callable)
	items[id] = item

func item_get(id: String) -> Item:
	if not item_has(id):
		return null
	return items[id]

func item_save() -> void:
	pass

func _item_dialogue(text: String) -> void:
	if BattleManager.active_battle:
		BattleManager.active_battle.start_dialogue(text, func():
			BattleManager.active_battle.battle_set_menu(Battle.BATTLE_MENU.BUTTON)
			BattleManager.start_enemy_turn()
		)
	else:
		print("Used Item outside battle:", text)

func _ready() -> void:
	# 注册默认示例物品
	register("PIE", "奶油馅饼", func():
		if Global.player_data.hp_max > 0:
			Global.player_data.hp = Global.player_data.hp_max
		_item_dialogue("* 你吃掉了奶油馅饼。\n* HP 完全恢复了！")
	)
	
	register("SNOWPIECE", "雪块", func():
		Global.player_data.hp = min(Global.player_data.hp + 45.0, max(Global.player_data.get("hp_max", 20.0), 20.0))
		_item_dialogue("* 你吃掉了雪块。\n* 恢复了 45 HP！")
	)
