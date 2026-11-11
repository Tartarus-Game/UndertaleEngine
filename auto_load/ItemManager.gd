extends Node
var items = {
	
}
func item_has(id : String):
	return items.has(id);

func register(id : String, item : Item):
	items[id] = item;
	item.id = id
	if item.get_parent() == null:
		add_child(item)

func item_get(id: String) -> Item:
	return items.get(id)

func item_save() -> Array[String]:
	return Global.player_get_items().duplicate()

func item_load(saved: Array[String]) -> void:
	Global.player_get_items().assign(saved)
	Global.player_stats_changed.emit()

func _ready() -> void:
	register("PROMISE", ItemTest.new());
	register("monster_candy", HealingItem.new("Monster Candy", 10, "Heals 10 HP."))
	register("spider_donut", HealingItem.new("Spider Donut", 12, "Heals 12 HP."))
	register("butts_pie", HealingItem.new("Butterscotch Pie", 0, "Fully restores HP.", true))
	register("toy_knife", EquipmentItem.new("Toy Knife", "weapon", 3, 30, "A training weapon."))
	register("ribbon", EquipmentItem.new("Faded Ribbon", "armor", 2, 20, "A little extra protection."))
	items.monster_candy.price = 10
	items.spider_donut.price = 7
	items.butts_pie.price = 50
