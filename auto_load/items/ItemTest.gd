extends Item

var _name : String = "";
var _desc : String = \
"""作者

[color=webgray]测试使用[/color]

[color=darkgreen]+ 回复 0 HP
[color=darkgoldenrod]= 测试：无效果
[color=darkred]- 不能吃
""";

func drop():
	pass
func name():
	return _name;
func info():
	return _desc;
