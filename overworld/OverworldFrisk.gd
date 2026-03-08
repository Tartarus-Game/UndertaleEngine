extends OverworldChar

@onready var AS : AnimatedSprite2D = $AnimatedSprite2D
@onready var RC : RayCast2D = $RayCast2D

var dir : String = "down"
var state : String = "idle"

func _physics_process(delta: float) -> void:
	var v = Input.get_vector("ui_left","ui_right","ui_up","ui_down").normalized()
	if(v):
		state = "move"
	else:
		state = "idle"
	move(v)
	super(delta)
	
func _process_move():
	for i in _movement:
		ray.target_position = i
		if(i.x != 0):
			if(i.x>0): 
				AS.flip_h = true
				dir = "right"
			if(i.x<0): 
				dir = "left"
				AS.flip_h = false
		if(i.y != 0):
			if(i.y>0): 
				dir = "down"
				AS.flip_h = false
			if(i.y<0): 
				dir = "up"
				AS.flip_h = false
		AS.play(state + "_" + dir)
			
		if(!ray.collide_with_areas):
			position += i
		else:
			continue
	_movement.clear()
