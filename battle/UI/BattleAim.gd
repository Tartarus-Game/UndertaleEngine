class_name BattleAim extends Control

signal aim_finished(precision: float, damage_mult: float, miss: bool)

@export var duration_frames: int = 90
var _is_aiming: bool = false
var _frames_passed: int = 0
var _start_x: float = 0.0
var _change_x: float = 0.0

@onready var bg = $Background
@onready var cursor = $Cursor

func start():
	# 进入瞄准阶段：重置游标并开始 90 帧线性移动。
	_is_aiming = true
	_frames_passed = 0
	show()
	
	# tml233 logic: Moves across the entire board width + cursor width over 90 frames
	var aim_width = cursor.size.x
	var board_width = bg.size.x
	
	# Move from left to right (can be randomized later)
	_start_x = -aim_width / 2.0
	_change_x = board_width + aim_width
	cursor.position.x = _start_x
	cursor.modulate = Color(1, 1, 1)

func _physics_process(_delta: float):
	# 每帧推进游标；超时未按确认则判定 MISS。
	if _is_aiming:
		_frames_passed += 1
		cursor.position.x = _start_x + _change_x * (float(_frames_passed) / duration_frames)
		
		# Miss check (out of bounds)
		if _frames_passed >= duration_frames:
			_miss()

func stop_aim():
	# 玩家按确认后停止瞄准，并按游标到中心距离计算倍率。
	if not _is_aiming:
		return
	
	var center = bg.size.x / 2.0
	var distance = abs(cursor.position.x - center)
	var width = bg.size.x / 2.0
	
	var damage_mult = 1.0
	var precision = 1.0 - (distance / width)
	
	if distance <= 12.0:
		damage_mult = 2.2 # Critical hit!
		cursor.modulate = Color(1, 1, 0) # Flash yellow
		
		# Blink animation
		var t = create_tween().set_loops(4)
		t.tween_property(cursor, "visible", false, 0.05)
		t.tween_property(cursor, "visible", true, 0.05)
	else:
		damage_mult = (1.0 - (distance / width)) * 2.0
	
	_finish(precision, damage_mult, false)

func _miss():
	# 超时 miss 分支。
	_finish(0.0, 0.0, true)

func _finish(precision: float, damage_mult: float, miss: bool):
	# 统一结束出口：关瞄准状态并把结果回调给 Battle.gd。
	_is_aiming = false
	emit_signal("aim_finished", precision, damage_mult, miss)
