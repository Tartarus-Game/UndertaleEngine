extends Node2D
class_name BattleButtonManager

@onready var fight = $Fight;
@onready var act = $Act;
@onready var item = $Item;
@onready var mercy = $Mercy;
@onready var select = $Select;
@onready var select_out = $Select_out;

@export var UIManager : BattleUIManager;

var button_slot : int = 0;

func get_button(slot : int):
	match slot:
		0:
			return fight;
		1:
			return act;
		2:
			return item;
		3:
			return mercy;
	return slot;
func get_button_position(slot : int):
	var button = get_button(slot);

	return button.get_node("Position").global_position;

func get_button_slot():
	return button_slot;

func button_set(slot : int):
	button_slot = slot;
	match(slot):
		-1:
			button_slot = 3;
			fight.frame = 0;
			act.frame = 0;
			item.frame = 0;
			mercy.frame = 1;
		0:
			fight.frame = 1;
			act.frame = 0;
			item.frame = 0;
			mercy.frame = 0;
		1:
			fight.frame = 0;
			act.frame = 1;
			item.frame = 0;
			mercy.frame = 0;
		2:
			fight.frame = 0;
			act.frame = 0;
			item.frame = 1;
			mercy.frame = 0;
		3:
			fight.frame = 0;
			act.frame = 0;
			item.frame = 0;
			mercy.frame = 1;
		4:
			button_slot = 0;
			fight.frame = 1;
			act.frame = 0;
			item.frame = 0;
			mercy.frame = 0;
