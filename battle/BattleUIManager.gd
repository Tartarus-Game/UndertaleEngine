class_name BattleUIManager extends Control;
@export var UI : Screen;

func add_UI(packed : PackedScene):
	UI = packed.instantiate()
	add_child(UI);

func get_ui() -> Screen:
	return UI;
