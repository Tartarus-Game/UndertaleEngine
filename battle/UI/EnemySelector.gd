class_name EnemySelection extends Control;
@onready var typer = $TextTyper;
@onready var hp = $HPMax/HP;
@onready var hp_max = $HPMax;

var _enemy_name : String = "";
var hp_max_value : float = 100;

func set_enemy_name(enemy_name : String):
	typer.text = "* "+ enemy_name;
	_enemy_name = enemy_name;
	
func set_enemy_hp(value : float):
	if(hp_max_value!=0):
		hp.size = Vector2(value/hp_max_value * 101, hp.size.y);

func set_enemy_max_hp(value : float):
	hp_max_value = value;

func hide_enemy_hp(enable : bool):
	hp_max.visible = !enable;

func set_is_choosed(enable : bool):
	if(!enable): 
		typer.text = "* " + _enemy_name;;
	else:
		typer.text = "  " + _enemy_name;
