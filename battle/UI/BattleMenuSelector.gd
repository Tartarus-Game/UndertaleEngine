class_name BattleMenuSelector extends RefCounted

var options : Array = []
var slot : int = 0

func set_options(next_options : Array, keep_slot : bool = false):
	options = next_options.duplicate()
	if options.is_empty():
		slot = 0
		return
	if keep_slot:
		slot = clampi(slot, 0, options.size() - 1)
		return
	slot = 0

func set_slot(next_slot : int, keep_slot : bool = false):
	if options.is_empty():
		slot = 0
		return
	if (not keep_slot):
		slot = next_slot #clampi(next_slot, 0, options.size() - 1)
	else: slot = clampi(next_slot, 0, options.size() - 1)
func move(offset : int):
	set_slot(slot + offset)

func get_slot() -> int:
	return slot

func get_size() -> int:
	return options.size()
