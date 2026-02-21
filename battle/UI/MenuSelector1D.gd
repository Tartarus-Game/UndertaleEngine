## MenuSelector1D
## 通用一维列表选择器，支持线性滚动与首尾循环。
## 独立于任何具体系统，可在菜单、物品栏、仁慈列表等处复用。
class_name MenuSelector1D extends RefCounted

## 是否在两端循环（slot 越界后绕回对侧）。
var wrap: bool = true

var _options: Array = []
var _slot: int = 0

# ── 数据设置 ─────────────────────────────────────────────────

## 重设选项列表。
## keep_slot=true 时保留当前下标（会被 clamp 合法化），否则重置为 0。
func set_options(next_options: Array, keep_slot: bool = false) -> void:
	_options = next_options.duplicate()
	if _options.is_empty():
		_slot = 0
		return
	if keep_slot:
		_slot = clampi(_slot, 0, _options.size() - 1)
	else:
		_slot = 0

## 直接跳到指定下标。
## wrap=true 时使用取模，wrap=false 时使用 clamp。
func set_slot(next_slot: int) -> void:
	if _options.is_empty():
		_slot = 0
		return
	if wrap:
		_slot = posmod(next_slot, _options.size())
	else:
		_slot = clampi(next_slot, 0, _options.size() - 1)

# ── 移动 ─────────────────────────────────────────────────────

## 向前/后移动 offset 步。
func move(offset: int) -> void:
	set_slot(_slot + offset)

# ── 读取 ─────────────────────────────────────────────────────

func get_slot() -> int:
	return _slot

func get_size() -> int:
	return _options.size()

## 返回当前选中的元素；列表为空时返回 null。
func get_selected() -> Variant:
	if _options.is_empty():
		return null
	return _options[_slot]
