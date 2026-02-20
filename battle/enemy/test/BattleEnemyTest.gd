extends BattleEnemy

func _ready():
	position = Vector2(320+200, 120);
	choice_box_size = Vector2(120, 230);

func init():
	super();
	set_enemy_name("test");
	action_set(1, "嘲讽", "嘲讽敌人，这无疑没有任何作用.");
	action_set(2, "祈祷", "唤醒仅存的良心，故作聪明.");
	action_set(3, "辱骂", "对着小蓝机器人辱骂吗，奇异搞笑.");
