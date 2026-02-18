extends Control
@onready var label = $Box/RichTextLabel;
@onready var selector = $Box/Mask/Selector;
@onready var mask = $Box/Mask;
@onready var selections = $Box/Mask/Selections;

var selection_packed : PackedScene = load("res://battle/UI/BattleEnemyActionSelection.tscn");
var actions : Array = [];
var action_nodes : Array = [];
var selection_slide = [0,0];
var enable : bool = false;
var lock_enable : bool = false;
var timer : float = 0
var slot : int = 0:
	set(val):
		if val != slot:
			label.visible_ratio = 0;
			selector.size.x = 0.2
			selector.modulate.a = 0.2

			if val > slot:
				selection_slide[0] += 1
			elif val < slot:
				selection_slide[0] -= 1

			slot = val

			if selection_slide[0] > 1:
				selection_slide[1] += 1
			elif selection_slide[0] < 0:
				selection_slide[1] -= 1

			selection_slide[0] = clampi(selection_slide[0],0,1)
			if selection_slide[1] < 0:
				selection_slide[1] = 0

var current_page : int = 0;

func _process(delta: float) -> void:
	label.visible_ratio = clampf(lerp(label.visible_ratio,1.1,1 - 0.1 ** delta),0.0,1.0);
	if enable:
		timer += 60 * delta;
		position.x = lerpf(position.x,240.0,1 - 0.001 ** delta)
		modulate.a = lerpf(
			modulate.a,
			1.0 if not lock_enable else 0.2,
			1 - 0.001 ** delta
		)
		selector.position.x = lerpf(
			selector.position.x,
			action_nodes[slot].position.x,
			1 - 0.00001 ** delta
		)
		selector.size.x = lerpf(selector.size.x,16.0,1 - 0.001 ** delta)
		selector.modulate.a = lerpf(selector.modulate.a,1.0, 1 - 0.1 ** delta)
		for _i in action_nodes:
			if action_nodes.find(_i) != 0:
				var before = action_nodes[action_nodes.find(_i) - 1];
				_i.position.x = lerp(
					_i.position.x,
					before.position.x + before.size.x + 24.0,
					1 - 0.000000001 ** delta
				);
			else:
				var offset = 0.0
				for _j in range(selection_slide[1]):
					if _j < action_nodes.size() and action_nodes.size() > 1:
						offset += (action_nodes[_j].size.x + 24.0);
					else:
						break
				_i.position.x = lerp(_i.position.x,32.0 - offset,1 - 0.000000001 ** delta);

			if slot == action_nodes.find(_i):
				_i.modulate = lerp(_i.modulate,Color(1.0,1.0,0.0,1.0),1 - 0.001 ** delta);
			else:
				_i.modulate = lerp(_i.modulate,Color(1.0,1.0,1.0,0.1),1 - 0.001 ** delta);
	else:
		position.x = lerpf(position.x,689.0,1 - 0.001 ** delta);
		modulate.a = lerpf(modulate.a,0.0,1 - 0.0001 ** delta);
		selection_slide = [0,0];
		
func set_action_label(text : String):
	label.text = "[b]||| " + text;

func clear_actions():
	for i in action_nodes:
		i.queue_free();
	actions.clear();
	action_nodes.clear();
	return;

func set_action_array(action_list : Array):
	clear_actions();
	actions = action_list.duplicate();
	for i in actions:
		var selection : RichTextLabel = selection_packed.instantiate();;
		selection.text = str(i[0]);
		action_nodes.append(selection);
		selections.add_child(selection);
	return;

func set_action_current_slot(_slot : int):
	slot = _slot;
	if(slot > current_page+1):
		current_page = slot - 1;

func set_enable(_enable : bool):
	enable = _enable;
	
func set_lock(_enable : bool):
	lock_enable = _enable;
