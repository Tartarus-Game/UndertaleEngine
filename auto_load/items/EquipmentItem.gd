class_name EquipmentItem extends Item

var display_name: String
var description: String


func _init(item_name: String, slot: String, bonus: int, cost: int, details: String) -> void:
	display_name = item_name
	equipment_slot = slot
	price = cost
	description = details
	if slot == "weapon":
		attack_bonus = bonus
	else:
		defense_bonus = bonus


func get_display_name() -> String:
	return display_name


func use() -> String:
	if Global.equip_item(id):
		return "* You equipped the %s." % display_name
	return "* You cannot equip the %s." % display_name


func info() -> String:
	var bonus := attack_bonus if equipment_slot == "weapon" else defense_bonus
	return "* %s\n* %s +%d. %s" % [display_name, equipment_slot.capitalize(), bonus, description]
