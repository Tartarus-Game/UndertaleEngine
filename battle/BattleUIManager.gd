class_name BattleUIManager extends Control;
@export var UI : BattleUI;

func add_UI(packed : PackedScene):
	UI = packed.instantiate()
	add_child(UI);

func get_ui():
	return UI;
