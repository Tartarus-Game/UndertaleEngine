class_name BattleMenuRendererVertical extends Control

## 竖排滚动菜单，参考 UnderTale-REALIZATION 的 select 系统实现。
## 与 BattleMenuRenderer 拥有相同的公共 API，可直接替换。
##
## 选中项完全可见，下方选项逐渐透明并右移形成级联；
## 上方选项向左滑出并淡出。所有过渡由 Tween 驱动。

const ITEM_SPACING := 30
const BASE_X := 40.0
const ANIM_DURATION := 0.35
const SOUL_OFFSET := Vector2(-28, 13)

var _options: Array = []
var _selected_slot: int = 0
var _option_nodes: Array = []
var _option_colors: Array = []
var _current_tween: Tween

@export var option_font: Font
@export var option_font_size: int = 26
@onready var _options_container: Node2D = $Options
@onready var page_label: Label = $PageIndicator

func show_menu(options: Array, selected: int) -> void:
	_options = options
	_rebuild_options()
	show()
	set_selected(selected)

func hide_menu() -> void:
	hide()

func set_selected(slot: int) -> void:
	if _options.is_empty(): return
	_selected_slot = clampi(slot, 0, maxi(0, _options.size() - 1))
	_animate_options()

func get_option_position(slot: int) -> Vector2:
	## 返回指定选项的 soul 定位点（目标位置，不受动画进度影响）。
	if _options.is_empty() or slot < 0 or slot >= _options.size():
		return global_position
	var offset = slot - _selected_slot
	var x: float
	var y: float
	if offset < 0:
		x = -50.0
		y = float(offset * ITEM_SPACING)
	else:
		x = float(offset * 5) + BASE_X
		y = float(offset * ITEM_SPACING)
	return _options_container.global_position + Vector2(x, y) + SOUL_OFFSET

func _rebuild_options() -> void:
	## 清除旧节点，为每个选项动态创建 Label。
	for node in _option_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_option_nodes.clear()
	_option_colors.clear()

	for i in range(_options.size()):
		var label = Label.new()
		var opt = _options[i]
		var text = ""
		var color = Color.WHITE

		if typeof(opt) == TYPE_DICTIONARY:
			text = opt.get("text", "")
			color = opt.get("color", Color.WHITE)
		else:
			text = str(opt)

		label.text = "* " + text
		label.position = Vector2(BASE_X, i * ITEM_SPACING)
		# 初始不可见，由首次 _animate_options 驱动入场
		label.modulate = Color(color.r, color.g, color.b, 0.0)

		if option_font:
			label.add_theme_font_override("font", option_font)
		label.add_theme_font_size_override("font_size", option_font_size)

		_options_container.add_child(label)
		_option_nodes.append(label)
		_option_colors.append(color)

	page_label.hide()

func _animate_options() -> void:
	## 根据 _selected_slot 驱动所有选项的位置与透明度动画。
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	_current_tween = create_tween().bind_node(self).set_parallel()
	_current_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	for i in range(_option_nodes.size()):
		var node = _option_nodes[i]
		if not is_instance_valid(node): continue
		var offset = i - _selected_slot
		var base_color = _option_colors[i]

		if offset < 0:
			# 选中项之上：向左滑出并淡出
			var target_pos = Vector2(-50, offset * ITEM_SPACING)
			var target_color = Color(base_color.r, base_color.g, base_color.b, 0.0)
			_current_tween.tween_property(node, "position", target_pos, ANIM_DURATION)
			_current_tween.tween_property(node, "modulate", target_color, ANIM_DURATION)
		else:
			# 选中项及以下：级联排列，逐渐透明
			var x = float(offset * 5) + BASE_X
			var target_pos = Vector2(x, offset * ITEM_SPACING)
			var alpha = maxf(0.0, 1.0 - offset * 0.3)
			var target_color = Color(base_color.r, base_color.g, base_color.b, alpha)
			_current_tween.tween_property(node, "position", target_pos, ANIM_DURATION)
			_current_tween.tween_property(node, "modulate", target_color, ANIM_DURATION)

	# 位置指示器
	if _options.size() > 1:
		page_label.text = str(_selected_slot + 1) + " / " + str(_options.size())
		page_label.show()
	else:
		page_label.hide()
