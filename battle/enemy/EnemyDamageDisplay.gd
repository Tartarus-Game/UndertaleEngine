extends Node2D

## 在敌人身上显示伤害数字 + 血条的组件
## 根据敌人的 choice_box_size 来决定血条宽度

var damage_value: float = 0.0
var hp_before: float = 0.0
var hp_after: float = 0.0
var hp_max: float = 1.0
var box_width: float = 100.0

var _timer := 0.0
var _phase := 0 # 0=数字上浮, 1=血条扣血动画, 2=等待消失
var _dmg_y_offset := 0.0
var _hp_bar_ratio := 1.0 # 当前显示的血量比例（动画用）
var _target_ratio := 1.0
var _font: Font

const DISPLAY_DURATION := 2.0
const NUMBER_RISE_SPEED := 40.0
const HP_BAR_HEIGHT := 12.0
const HP_BAR_Y_OFFSET := 20.0

func _ready():
	_font = load("res://resources/font/Mars Needs Cunnilingus.ttf")
	z_index = 100
	print("[DamageDisplay] _ready called, font loaded: ", _font != null)

func setup(dmg: float, hp_before_val: float, hp_after_val: float, hp_max_val: float, box_w: float):
	damage_value = dmg
	hp_before = hp_before_val
	hp_after = hp_after_val
	hp_max = max(hp_max_val, 1.0)
	box_width = max(box_w, 40.0)
	_hp_bar_ratio = hp_before / hp_max
	_target_ratio = hp_after / hp_max
	_timer = 0.0
	_phase = 0
	_dmg_y_offset = 0.0
	print("[DamageDisplay] setup: ratio=", _hp_bar_ratio, " target=", _target_ratio, " box_w=", box_width)

func _process(delta: float):
	_timer += delta
	
	match _phase:
		0: # 数字上浮阶段
			_dmg_y_offset += NUMBER_RISE_SPEED * delta
			if _timer > 0.5:
				_phase = 1
				_timer = 0.0
		1: # 血条扣血动画
			_hp_bar_ratio = move_toward(_hp_bar_ratio, _target_ratio, delta * 1.2)
			if abs(_hp_bar_ratio - _target_ratio) < 0.001:
				_hp_bar_ratio = _target_ratio
				_phase = 2
				_timer = 0.0
		2: # 等待消失
			if _timer > 0.8:
				queue_free()
				return
	
	queue_redraw()

func _draw():
	# ——— 伤害数字 ———
	var dmg_text = str(int(damage_value))
	if damage_value <= 0:
		dmg_text = "MISS"
	
	var font_size := 32
	if _font:
		var text_size = _font.get_string_size(dmg_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = Vector2(-text_size.x / 2.0, -30.0 - _dmg_y_offset)
		
		# 黑色描边
		for ox in [-2, 0, 2]:
			for oy in [-2, 0, 2]:
				if ox != 0 or oy != 0:
					draw_string(_font, text_pos + Vector2(ox, oy), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)
		
		# 白色/灰色数字
		var num_color = Color.WHITE if damage_value > 0 else Color(0.5, 0.5, 0.5)
		draw_string(_font, text_pos, dmg_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, num_color)
	
	# ——— 血条 ———
	var bar_w = box_width
	var bar_h = HP_BAR_HEIGHT
	var bar_x = - bar_w / 2.0
	var bar_y = HP_BAR_Y_OFFSET
	
	# 背景（深红）
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.2, 0.0, 0.0))
	
	# 当前动画中的血量比例（黄色，从 hp_before 逐渐缩短到 hp_after）
	var yellow_w = bar_w * _hp_bar_ratio
	if yellow_w > 0.5:
		draw_rect(Rect2(bar_x, bar_y, yellow_w, bar_h), Color(1.0, 0.8, 0.0))
	
	# 目标血量（绿色，立即显示最终值）
	var green_w = bar_w * _target_ratio
	if green_w > 0.5:
		draw_rect(Rect2(bar_x, bar_y, green_w, bar_h), Color(0.0, 0.85, 0.0))
	
	# 边框
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color.WHITE, false, 2.0)
