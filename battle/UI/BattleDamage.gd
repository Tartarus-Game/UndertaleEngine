class_name BattleDamage extends Node2D

@export var vspeed: float = -2.666667
@export var gravity: float = 0.25
@export var display_time_frames: int = 60
@export var font: Font

var _timer: int = 0
var _ystart: float = 0.0

@onready var label: Label = $Label
@onready var bar_bg: ColorRect = $BarBg
@onready var bar_fill: ColorRect = $BarBg/BarFill

func _ready() -> void:
	# 记录初始 Y 作为落地线，初始隐藏。
	_ystart = position.y
	hide()

func start(damage: int, max_hp: int, current_hp: int) -> void:
	# 初始化伤害弹字：支持 MISS 文本或数字 + HP 条。
	show()
	_ystart = position.y
	
	if damage <= 0:
		label.text = "MISS"
		label.add_theme_color_override("font_color", Color.GRAY)
		bar_bg.hide()
	else:
		label.text = str(damage)
		label.add_theme_color_override("font_color", Color.RED)
		
		# Setup HP Bar
		bar_bg.show()
		var fill_ratio = float(current_hp) / max_hp
		fill_ratio = clamp(fill_ratio, 0.0, 1.0)
		bar_fill.size.x = bar_bg.size.x * fill_ratio

func _physics_process(_delta: float) -> void:
	# 按 tml233 参数做抛物线跳字，并在寿命结束后销毁。
	if not visible:
		return
		
	_timer += 1
	
	# Physics
	position.y += vspeed
	vspeed += gravity
	
	# Clamp at floor
	if position.y > _ystart:
		position.y = _ystart
		vspeed = 0.0
		gravity = 0.0
		
	# Death timer
	if _timer > display_time_frames:
		queue_free()
