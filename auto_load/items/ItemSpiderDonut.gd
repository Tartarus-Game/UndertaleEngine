extends Item

var _name : String = "Spider Donut";
var _desc : String = \
"""Spider Donut

[color=webgray]蜘蛛烘焙坊制作的甜甜圈[/color]

[color=darkgreen]+ 回复 12 HP
""";

func use():
	Global.player_data.hp = min(Global.player_data.hp + 12, Global.player_data.hp_max)

func drop():
	pass
func name():
	return _name;
func info():
	return _desc;
