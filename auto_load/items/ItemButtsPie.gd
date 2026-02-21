extends Item

var _name : String = "Butterscotch Pie";
var _desc : String = \
"""Butterscotch Pie

[color=webgray]奶油糖果肉桂派，带着家的味道[/color]

[color=darkgreen]+ 完全回复 HP
""";

func use(index: int, inventory: Array):
	Global.player_data.hp = Global.player_data.hp_max
	DialogueManager.add_dialogue("* You ate Butterscotch Pie\n* 简直难吃,但是你的生命值满了.",\
	func(t): t.pause = true)
	inventory.remove_at(index)

func drop(index: int, inventory: Array):
	inventory.remove_at(index)

func name():
	return _name;
func info(index: int, inventory: Array):
	return _desc;
