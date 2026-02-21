class_name BattleItemManager extends Control

@onready var selections: Array[RichTextLabel] = [
	$TextTyper1,
	$TextTyper2,
	$TextTyper3
];
@onready var counter = $Slot;

var items: Array[String] = [];
var page: int = 0;
var _slot: int = 0;

func set_items(items_name: Array[String]):
	items = items_name;

func hide_all(enable: bool):
	for i in selections:
		i.visible = !enable;
	counter.visible = !enable;

func set_slot(slot: int):
	_slot = slot;
	while (_slot < page):
		page -= 1;
	while (_slot > page + 2):
		page += 1;
	counter.visible = true;
	for i in range(3):
		var index = page + i;
		if (len(items) > index):
			var _name: String = items[index];
			selections[i].visible = true;
			selections[i].text = "* " + _name;
		else:
			selections[i].visible = false;
	counter.text = "(" + str(slot + 1) + "/" + str(len(items)) + ")";
