class_name BattleSoulRed extends CharacterBody2D;

var _move_scale : float = 1
var _move_speed = {
	0: 2,
	90: 2,
	180: 2,
	270: 2
}
var move_able := false
var _key_to_move = {
	"ui_left": 180,
	"ui_right": 0,
	"ui_down": 270,
	"ui_up": 90
}

func hurt(bullet : BattleBullet):
	pass;

func set_move_able(able: bool):
	move_able = able;

func _physics_process(delta: float) -> void:
	if(move_able):
		var move := Vector2.ZERO
		if(Input.is_action_pressed("ui_left")):
			move.x += -_move_speed[180] * _move_scale
		if(Input.is_action_pressed("ui_right")):
			move.x += _move_speed[0] * _move_scale
		if(Input.is_action_pressed("ui_down")):
			move.y += -_move_speed[270] * _move_scale
		if(Input.is_action_pressed("ui_up")):
			move.y += _move_speed[90] * _move_scale
		move_and_collide(move)
