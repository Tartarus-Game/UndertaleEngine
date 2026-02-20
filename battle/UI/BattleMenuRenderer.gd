class_name BattleMenuRenderer extends Control

const COLUMNS := 2
const ROWS := 3
const OPTIONS_PER_PAGE := 6

var _options: Array = []
var _selected_slot: int = 0

@onready var labels: Array = [
	$Option0, $Option1, $Option2, $Option3, $Option4, $Option5
]
@onready var page_label = $PageIndicator

func show_menu(options: Array, selected: int) -> void:
	_options = options
	show()
	set_selected(selected)

func hide_menu() -> void:
	hide()

func set_selected(slot: int) -> void:
	if _options.is_empty(): return
	_selected_slot = clampi(slot, 0, maxi(0, _options.size() - 1))
	_rebuild_labels()

func get_option_position(slot: int) -> Vector2:
	if _options.is_empty(): return global_position
	var page = slot / OPTIONS_PER_PAGE
	var current_page = _selected_slot / OPTIONS_PER_PAGE
	if page != current_page: return global_position
	var index = slot % OPTIONS_PER_PAGE
	return labels[index].global_position

func _rebuild_labels() -> void:
	var current_page = _selected_slot / OPTIONS_PER_PAGE
	var start_idx = current_page * OPTIONS_PER_PAGE
	
	for i in range(OPTIONS_PER_PAGE):
		var opt_idx = start_idx + i
		if opt_idx < _options.size():
			var opt = _options[opt_idx]
			var text = ""
			var color = Color.WHITE
			
			if typeof(opt) == TYPE_DICTIONARY:
				text = opt.get("text", "")
				color = opt.get("color", Color.WHITE)
			else:
				text = str(opt)
			
			labels[i].text = "* " + text
			
			if opt_idx == _selected_slot:
				labels[i].modulate = Color(1, 1, 0) # Yellow for selected
			else:
				labels[i].modulate = color
			labels[i].show()
		else:
			labels[i].hide()
			
	var total_pages = ceil(float(_options.size()) / OPTIONS_PER_PAGE)
	if total_pages > 1:
		page_label.text = "PAGE " + str(current_page + 1) + " / " + str(total_pages)
		page_label.show()
	else:
		page_label.hide()
