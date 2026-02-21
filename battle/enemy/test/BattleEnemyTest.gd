extends BattleEnemy

func _ready():
	choice_box_size = Vector2(120, 230);

func init():
	super ();
	data.name = "test"
	data.hp = 100
	data.hp_max = 100
	action_set(1, "笑话", Callable(self , "_on_joke"));
	action_set(2, "祈祷", Callable(self , "_on_pray"));
	action_set(3, "拥抱", Callable(self , "_on_hug"));

func _act_dialogue(text: String):
	if battle:
		battle.start_dialogue(text, func():
			battle.battle_set_menu(Battle.BATTLE_MENU.BUTTON)
			BattleManager.start_enemy_turn()
		)
	else:
		print("Act Text: ", text)

func _on_joke():
	_act_dialogue("你讲了一个并不好笑的冷笑话。\n* 沙包似乎没有反应。")

func _on_pray():
	_act_dialogue("你为沙包祈祷。\n* 它恢复了 10 点 HP！")
	if data:
		data.hp = min(data.hp + 10, data.hp_max)

func _on_hug():
	_act_dialogue("你紧紧抱住了沙包。\n* 感觉它有些扎手。")
	

func process_turn(time_elapsed: float) -> void:
	if time_elapsed > +1.0:
		print("test 敌人的攻击结束了！等待一秒后回到菜单")
		BattleManager.stop_enemy_turn()
