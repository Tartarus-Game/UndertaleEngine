class_name BattleButtonManager extends Node2D

@onready var fight = $Fight
@onready var act = $Act
@onready var item = $Item
@onready var mercy = $Mercy
@onready var select = $Select
@onready var select_out = $Select_out

@export var UIManager: BattleUIManager

## 按钮节点列表，顺序对应槽位 0-3
var _buttons: Array

const BUTTON_COUNT := 4

func _ready() -> void:
	_buttons = [fight, act, item, mercy]

func get_button(slot: int) -> Node:
	if slot < 0 or slot >= _buttons.size():
		return null
	return _buttons[slot]

func get_button_slot() -> int:
	for i in range(_buttons.size()):
		if _buttons[i].frame == 1:
			return i
	return 0

## 设置高亮槽位（支持环绕：-1→3，4→0）
func button_set(slot: int) -> void:
	var clamped := posmod(slot, BUTTON_COUNT)
	for i in range(_buttons.size()):
		_buttons[i].frame = 1 if i == clamped else 0
