extends BattleEnemy

func _ready():
	position = Vector2(320+200, 120);
	choice_box_size = Vector2(120, 230);

func init():
	super();
	set_enemy_name("test");
	action_set(1, "嘲讽", "* 嘲讽敌人，这无疑没有任何作用.");
	action_set(2, "祈祷", "* 你祈祷你今天能吃上一顿好的.");
	action_set(3, "辱骂", "* 对着小蓝机器人辱骂吗，奇异搞笑.");
	action_set(4, "测试", "* 正在进行测试...");
	action_set(5, "求饶", "* 不能吧.");

func on_battle_menu_changed(_type, _state, _from):
	super(_type, _state, _from)
	if(_type == Battle.EVENT_TYPE.ACT_CONFIRMED and self == battle.battle_get_act_enemy_choice()):
		match(battle.battle_act_choice):
			1:
				DialogueManager.add_dialogue("* 嘲讽敌人，这无疑没有任何作用.",\
					func(t): t.pause = true)
			2:
				DialogueManager.add_dialogue("* 你祈祷你今天能吃上一顿好的.",\
					func(t): t.pause = true)
			3:
				DialogueManager.add_dialogue("* 对着小蓝机器人辱骂吗，奇异搞笑.",\
					func(t): t.pause = true)
			4:
				DialogueManager.add_dialogue("* 正在进行测试...",\
					func(t): t.pause = true)
			5:
				DialogueManager.add_dialogue("* 不能吧.",\
					func(t): t.pause = true)
				
