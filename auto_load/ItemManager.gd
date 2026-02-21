extends Node
var items = {
	
}

func _ready():
	_register_items()
	_add_test_items()

func _register_items():
	var monster_candy = preload("res://auto_load/items/ItemMonsterCandy.gd").new()
	register("monster_candy", monster_candy)
	
	var spider_donut = preload("res://auto_load/items/ItemSpiderDonut.gd").new()
	register("spider_donut", spider_donut)
	
	var butts_pie = preload("res://auto_load/items/ItemButtsPie.gd").new()
	register("butts_pie", butts_pie)

func _add_test_items():
	Global.player_data_items.append(item_get("monster_candy"))
	Global.player_data_items.append(item_get("spider_donut"))
	Global.player_data_items.append(item_get("butts_pie"))

func item_has(id : String):
	return items.has(id);

func register(id : String, item : Item):
	items[id] = item;

func item_get(id: String):
	if !item_has(id): return;
	return items[id];

func item_save():
	pass
