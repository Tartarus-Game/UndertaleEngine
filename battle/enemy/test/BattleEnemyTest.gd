extends BattleEnemy

func _ready():
	position = Vector2(320+200, 120);
	choice_box_size = Vector2(120, 230);

func init():
	super();
	set_enemy_name("test");
	action_set(1, "嘲讽");
	action_set(2, "祈祷");
	action_set(3, "辱骂");
