extends Node
var items = {
	
}
func item_has(id : String):
	return items.has(id);

func register(id : String, item : Item):
	items[id] = item;
	if item.get_parent() == null:
		add_child(item)

func item_get(id: String) -> Item:
	return items.get(id)

func item_save():
	pass

func _ready() -> void:
	register("PROMISE", ItemTest.new());
	register("monster_candy", HealingItem.new("Monster Candy", 10, "Heals 10 HP."))
	register("spider_donut", HealingItem.new("Spider Donut", 12, "Heals 12 HP."))
	register("butts_pie", HealingItem.new("Butterscotch Pie", 0, "Fully restores HP.", true))
