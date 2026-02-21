extends Item

var _name : String = "Butterscotch Pie";
var _desc : String = \
"""Butterscotch Pie

[color=webgray]奶油糖果肉桂派，带着家的味道[/color]

[color=darkgreen]+ 完全回复 HP
""";

func use():
	Global.player_data.hp = Global.player_data.hp_max

func drop():
	pass
func name():
	return _name;
func info():
	return _desc;
