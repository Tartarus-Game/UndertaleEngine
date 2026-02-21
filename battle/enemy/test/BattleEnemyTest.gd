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

func _on_joke():
	print("test: 讲了个笑话")

func _on_pray():
	print("test: 开始祈祷")

func _on_hug():
	print("test: 抱了抱你")

func process_turn(time_elapsed: float) -> void:
	if time_elapsed > +1.0:
		print("test 敌人的攻击结束了！等待一秒后回到菜单")
		BattleManager.stop_enemy_turn()
