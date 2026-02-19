class_name EnemySelections extends Control

@onready var selections : Array[EnemySelection] = [
	$EnemySelector1,
	$EnemySelector2,
	$EnemySelector3
];

func hide_enemy(slot : int, enable : bool):
	selections[slot].visible = !enable;

func set_enemy_info(slot : int,enemy_name : String, enemy_hp : float, enemy_hp_max : float):
	selections[slot].set_enemy_name(enemy_name);
	selections[slot].set_enemy_max_hp(enemy_hp_max);
	selections[slot].set_enemy_hp(enemy_hp);

func hide_info(enable : bool):
	for i in selections:
		i.hide_enemy_hp(enable);

func set_slot(slot : int):
	var count : int = 0;
	for i in selections:
		if(count == slot):
			i.set_is_choosed(true);
		else:
			i.set_is_choosed(false);
		count += 1;
