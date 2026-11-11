class_name Item extends Node

var _slot = -1;
var id := ""
var consumable := false
var droppable := true
var price := 0
var equipment_slot := ""
var attack_bonus := 0
var defense_bonus := 0

func get_display_name() -> String:
	return "Item"

func use():
	return "* Nothing happened."
func drop():
	return "* You dropped the item."
func name():
	return get_display_name()
func info():
	return "* An item."
