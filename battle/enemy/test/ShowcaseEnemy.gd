extends BattleEnemy

func init() -> void:
	super()
	set_enemy_name("Pattern Dummy")
	data.exp_reward = 10
	data.gold_reward = 25
	data.attack = 3
	wave_scene = preload("res://battle/waves/PatternShowcase.tscn")
	action_set(1, "Talk", func():
		spareable = true
		return "* You made friends with the dummy."
	)


func get_turn_dialog() -> String:
	return "* Watch out for the patterns!"
