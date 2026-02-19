extends Node
var items = {
	
}
func item_has(id : String):
	return items.has(id);

func register(id : String, item : Item):
	items[id] = item;

func item_get(id: String):
	if !item_has(id): return;
	return items[id];

func item_save():
	pass

func _ready() -> void:
	register("PROMISE", ItemTest.new());
