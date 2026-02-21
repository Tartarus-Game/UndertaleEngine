class_name BattleEnemyActions extends Control
@onready var selections : Array[EnemyActionSelection] = [
	$EnemyActionSelection1,
	$EnemyActionSelection2,
	$EnemyActionSelection3,
	$EnemyActionSelection4,
	$EnemyActionSelection5,
	$EnemyActionSelection6
];

func set_actions_name(action_names : Array[String]):
	for i in range(6):
		if(len(action_names)>i):
			var _name = action_names[i];
			selections[i].visible = true;
			selections[i].set_action_name(_name);
		else:
			selections[i].visible = false;

func hide_all_actions(enable : bool):
	for i in selections:
		i.visible = !enable;
