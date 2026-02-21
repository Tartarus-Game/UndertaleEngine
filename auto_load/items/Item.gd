class_name Item extends Node

var _slot = -1;

func use(index: int, inventory: Array):
	inventory.remove_at(index)
func drop(index: int, inventory: Array):
	inventory.remove_at(index)
func info(index: int, inventory: Array):
	pass
func name():
	pass
