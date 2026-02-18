extends Control;
@onready var box = $Box;
@onready var enemy_name = $Box/Info/HBoxContainer/Name
@onready var enemy_lv = $Box/Info/HBoxContainer/LV
@onready var atk = $Box/Info/ATKandDEF/Atk
@onready var def = $Box/Info/ATKandDEF/Def
@onready var enemy_hp_bar = $Box/HPBar;

var enemy_current_name : String = "enemy";
var enemy_current_lv : String = "lv:???";
var enemy_current_atk : String = "atk:0";
var enemy_current_def : String = "def:0";
var enemys = [];
var current_enemy : BattleEnemy;

var _timer : float = 0;
var _color : Color = Color.RED;
var _position : Vector2 = Vector2(0, 0);
var _width : float = 150;
var _height : float = 150;
var _t : Tween;

func _ready() -> void:
	_position = Vector2(320, 580);

func _process(delta: float) -> void:
	_timer += 60 * delta;
	box.size = lerp(box.size, Vector2(_width, _height), 1 - 0.005 ** delta);
	box.position = lerp(box.position, _position - box.size / 2, 1 - 0.0001 ** delta);
	modulate.a = lerp(modulate.a,1.0,1 - 0.01 ** delta);
	self_modulate = _color;
	self_modulate.a = 0.2 + abs(sin(_timer * 0.05) * 0.8);
	enemy_hp_bar.size = box.size;
	enemy_hp_bar.modulate.a = sin(_timer * 0.025);
	if !(len(enemys) > 0 and current_enemy):return;
	for i in enemys:
		if(i!=current_enemy):
			i.modulate.v = clamp(lerpf(i.modulate.v,0.29,1 - 0.01 ** delta),0.3,1.0);
		else:
			current_enemy.modulate.v = clamp(lerpf(current_enemy.modulate.v,1.1,1 - 0.01 ** delta),\
				0.3,1.0);

func exit_enemy_choice():
	current_enemy = null;
	if(len(enemys) == 0):return;
	for i in enemys:
		i.modulate.v = 1;
	enemys = [];
	collapse();
	
func set_box_position_and_size(pos : Vector2, _size : Vector2):
	_position = pos;
	_width = _size.x;
	_height = _size.y;

func set_box_position(pos : Vector2):
	_position = pos;

func set_box_size(_size : Vector2):
	_width = _size.x;
	_height = _size.y;
	
func set_enemy_name(_enemy_name : String):
	enemy_current_name = str(_enemy_name);
	enemy_name.text = _enemy_name;

func set_enemy_lv(_enemy_lv : String):
	enemy_current_lv = str(_enemy_lv);
	enemy_lv.text = "LV:" + str(_enemy_lv);
	
func set_enemy_def_text(text : String):
	enemy_current_atk = text;
	def.text = "def:" + text;
	
func set_enemy_atk_text(text : String):
	enemy_current_def = text;
	atk.text = "atk:" + text

func collapse():
	if(_t):
		_t.kill();
	_position = Vector2(320, 580);
	_width = 150;
	_height = 150;

func hide_info(enable : bool):
	if(enable):
		enemy_name.text = "???";
		enemy_lv.text = "??";
		def.text = "???";
		atk.text = "???";
	else:
		enemy_name.text = enemy_current_name;
		enemy_lv.text = enemy_current_lv;
		def.text = enemy_current_def;
		atk.text = enemy_current_atk;
