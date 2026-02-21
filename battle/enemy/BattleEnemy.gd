class_name BattleEnemy extends Node2D

var battle : Battle;

var choice_box_size : Vector2 = Vector2(100, 100);
var choice_box_offset : Vector2 = Vector2(0, 0);
var _checked : bool = false;
var _spareable : bool = false;
var _can_flee : bool = true;
var _hp : float = 200;
var _hp_max : float = 200;
var _actions = [];
var _name : String = "null";

func _ready():
	position = Vector2(320, 120);

func init():
	# 敌人初始化：订阅 Battle 事件并注入默认 ACT 文本。
	battle.BattleEvent.connect(on_battle_menu_changed);
	action_set(0, "检查", "* 检查敌人的属性，获得准确的数值。");

func on_battle_menu_changed(_type, _state, _from):
	# 给子类重写：根据菜单变化更新敌人的行为/动画。
	pass;

func set_checked(enable : bool):
	_checked = enable;
	return;

func get_is_checked() -> bool:
	return _checked;

func set_spareable(enable: bool):
	# 是否可被 Spare（黄名判定）。
	_spareable = enable;

func get_spareable() -> bool:
	return _spareable;

func get_can_flee() -> bool:
	# 当前敌人是否允许玩家 Flee。
	return _can_flee;

func get_hp() -> int:
	return _hp;

func get_hp_max() -> int:
	return _hp_max;

func set_hp(val: float):
	# 生命值写入时自动限制在 [0, hp_max]。
	_hp = clampf(val, 0, _hp_max)

func set_enemy_name(__name : String):
	_name = __name;

func get_enemy_name() -> String:
	return _name;

func action_get_count() -> int:
	return _actions.size();

func get_actions():
	return _actions;

func action_set(slot : int, text : String, desc : String):
	# 配置 ACT 列表项：显示名 + 描述文本。
	if(action_get_count() < slot): return;
	_actions.resize(_actions.size()+1);
	_actions.set(slot, [text, desc]);
	
func action_get_name(slot : int) -> String:
	if(action_get_count() <= slot): return "";
	return _actions[slot][0];
	
func action_get_desc(slot : int)-> String:
	if(action_get_count() <= slot): return "";
	return _actions[slot][1];

## 返回该敌人本回合要显示的台词，子类可覆写。
func get_turn_dialog() -> String:
	# 返回该敌人本回合要显示的台词，子类可覆写。
	return ""
## 返回该敌人遇到时的介绍文本，子类可覆写。
func get_encounter_dialog() -> String:
	return "";
