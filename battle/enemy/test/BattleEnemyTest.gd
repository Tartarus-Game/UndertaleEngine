extends BattleEnemy

const TestBulletScene = preload("res://battle/enemy/test/TestBullet.gd")
var _current_bullet: Node2D = null
var _turn_started: bool = false
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
	if not _turn_started:
		_turn_started = true
		_current_bullet = TestBulletScene.new()
		# Add to battle or enemy so it renders properly inside the box
		# The box is centered at (320, 320), size 140x140 during shrinking.
		# Let's spawn near the top of the box.
		if battle:
			battle.add_child(_current_bullet)
			_current_bullet.position = Vector2(320, 270)
		else:
			add_child(_current_bullet)
			_current_bullet.position = Vector2(0, -50)
		
	# Simple bullet movement: fall down slowly
	if _current_bullet and is_instance_valid(_current_bullet):
		_current_bullet.position.y += 60.0 * get_process_delta_time()

	if time_elapsed > +3.0:
		_turn_started = false
		if _current_bullet and is_instance_valid(_current_bullet):
			_current_bullet.queue_free()
			_current_bullet = null
		BattleManager.stop_enemy_turn()
