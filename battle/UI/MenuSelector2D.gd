## MenuSelector2D
## 通用二维网格选择器，支持按行/列独立移动，X/Y 方向独立配置循环。
## 内部以一维 flat-index 存储，通过 columns 换算行列。
## 独立于任何具体系统，可在 ACT 列表、物品格等处复用。
class_name MenuSelector2D extends RefCounted

## X 方向（列）是否循环。
var wrap_x: bool = false
## Y 方向（行）是否循环。
var wrap_y: bool = false

var _options: Array = []
var _columns: int = 1
var _slot: int = 0

# ── 数据设置 ─────────────────────────────────────────────────

## 重设选项列表与列数。
## keep_slot=true 时保留当前下标（会被 clamp 合法化），否则重置为 0。
func set_options(next_options: Array, next_columns: int = 1, keep_slot: bool = false) -> void:
	_options = next_options.duplicate()
	_columns = max(1, next_columns)
	if _options.is_empty():
		_slot = 0
		return
	if keep_slot:
		_slot = clampi(_slot, 0, _options.size() - 1)
	else:
		_slot = 0

## 直接跳到指定 flat-index（clamp 到合法范围）。
func set_slot(next_slot: int) -> void:
	if _options.is_empty():
		_slot = 0
		return
	_slot = clampi(next_slot, 0, _options.size() - 1)

## 通过行列跳到指定格子，支持 wrap_x/wrap_y 独立循环。
func set_cell(row: int, col: int) -> void:
	if _options.is_empty():
		return
	var rows = get_row_count()
	if wrap_y:
		row = posmod(row, rows)
	else:
		row = clampi(row, 0, rows - 1)
	if wrap_x:
		col = posmod(col, _columns)
	else:
		col = clampi(col, 0, _columns - 1)
	# 该格子可能超出实际选项数（末行不满），clamp 保底。
	set_slot(row * _columns + col)

# ── 移动 ─────────────────────────────────────────────────────

## 水平移动（左/右），offset 为 ±1。
func move_x(offset: int) -> void:
	set_cell(get_row(), get_col() + offset)

## 垂直移动（上/下），offset 为 ±1。
func move_y(offset: int) -> void:
	set_cell(get_row() + offset, get_col())

# ── 读取 ─────────────────────────────────────────────────────

func get_slot() -> int:
	return _slot

func get_row() -> int:
	return _slot / _columns

func get_col() -> int:
	return _slot % _columns

## 总选项数。
func get_size() -> int:
	return _options.size()

## 实际行数（末行不满时仍计一行）。
func get_row_count() -> int:
	if _options.is_empty():
		return 0
	return ceili(float(_options.size()) / float(_columns))

## 列数。
func get_col_count() -> int:
	return _columns

## 返回当前选中的元素；列表为空时返回 null。
func get_selected() -> Variant:
	if _options.is_empty():
		return null
	return _options[_slot]
