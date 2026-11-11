class_name Item extends Node

var _slot = -1;
var consumable := false
var droppable := true

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
