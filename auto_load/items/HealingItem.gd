class_name HealingItem extends Item

var display_name: String
var healing: int
var description: String
var full_heal: bool


func _init(item_name: String, amount: int, item_description: String, restores_all := false) -> void:
	display_name = item_name
	healing = amount
	description = item_description
	full_heal = restores_all
	consumable = true


func get_display_name() -> String:
	return display_name


func info() -> String:
	return "* %s\n* %s" % [display_name, description]


func use() -> String:
	var before: int = Global.player_data.hp
	Global.player_heal(int(Global.player_data.hp_max) if full_heal else healing)
	var restored: int = int(Global.player_data.hp) - before
	return "* You ate the %s.\n* Recovered %d HP." % [display_name, restored]


func drop() -> String:
	return "* You dropped the %s." % display_name
