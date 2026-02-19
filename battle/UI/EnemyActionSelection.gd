class_name EnemyActionSelection extends Control

@onready var typer = $typer;

func set_action_name(action_name : String):
	typer.text = "* "+action_name;
