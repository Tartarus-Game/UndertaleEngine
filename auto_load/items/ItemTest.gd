class_name ItemTest extends Item

var _name : String = "PROMISE";
var _desc : String = \
"""作者

[color=webgray]测试使用[/color]

[color=darkgreen]+ 回复 0 HP[/color]
[color=darkgoldenrod]= 测试：无效果[/color]
[color=darkred]- 不能吃[/color]
""";

func use():
	return "* You cannot eat the PROMISE."

func get_display_name() -> String:
	return _name

func drop():
	return "* You let go of the PROMISE."
func name():
	return _name;
func info():
	return _desc;
