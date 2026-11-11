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

func perform_action(slot: int) -> String:
	if slot == 1:
		spareable = true
		return "* You talked. The enemy can be spared."
	if slot == 2:
		_hp = minf(_hp_max, _hp + 10.0)
		return "* You prayed. The enemy recovered 10 HP."
	if slot == 3:
		return "* You shouted at the little robot."
	return super(slot)

func get_turn_dialog() -> String:
	return "* The little robot watches you."
