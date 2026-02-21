extends Item

var _name : String = "Monster Candy";
var _desc : String = \
"""Monster Candy

[color=webgray]从万圣节碗里拿的糖果[/color]

[color=darkgreen]+ 回复 10 HP
""";

func use(index: int, inventory: Array):
	Global.player_data.hp = min(Global.player_data.hp + 10, Global.player_data.hp_max)
	
	inventory.remove_at(index)

func drop(index: int, inventory: Array):
	pass
func name():
	return _name;
func info(index: int, inventory: Array):
	return _desc;
