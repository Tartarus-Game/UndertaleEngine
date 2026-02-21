extends BattleEnemy

func _ready():
	position = Vector2(320+200, 120);
	choice_box_size = Vector2(120, 230);

func init():
	super();
	set_enemy_name("test");
	action_set(1, "嘲讽", "嘲讽敌人，这无疑没有任何作用.");
	action_set(2, "祈祷", "你祈祷你今天能吃上一顿好的.");
	action_set(3, "辱骂", "对着小蓝机器人辱骂吗，奇异搞笑.");
func get_encounter_dialog() -> String:
	return "* 请不要把巨石一次又一次的推上山顶。"
