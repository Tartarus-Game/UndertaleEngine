class_name BattleEnemy extends Node2D

var battle: Battle

var choice_box_size: Vector2 = Vector2(100, 100)
var choice_box_offset: Vector2 = Vector2(0, 0)
var _is_checked: bool = false
const EnemyDataRes = preload("res://battle/enemy/EnemyData.gd")
@export var data: Resource

var _action_names: Array[String] = []
var _action_callbacks: Array[Callable] = []

func _init() -> void:
	if not data:
		data = EnemyDataRes.new()

func _ready() -> void:
	pass

func take_damage(attack_power: float) -> float:
	var def = data.defense if data else 0.0
	var damage = max(0.0, attack_power - def)
	var hp_before = data.hp if data else 0.0
	if data:
		data.hp -= damage
		if data.hp < 0:
			data.hp = 0
	var hp_after = data.hp if data else 0.0
	show_damage(damage, hp_before, hp_after)
	return damage

## 在敌人身上生成伤害数字 + 血条显示
const EnemyDamageDisplayScript = preload("res://battle/enemy/EnemyDamageDisplay.gd")

func show_damage(dmg: float, hp_before: float, hp_after: float) -> void:
	var display = EnemyDamageDisplayScript.new()
	add_child(display)
	display.setup(dmg, hp_before, hp_after, data.hp_max if data else 100.0, choice_box_size.x)
	print("[DamageDisplay] spawned: dmg=", dmg, " hp_before=", hp_before, " hp_after=", hp_after, " box_w=", choice_box_size.x)

func process_turn(time_elapsed: float) -> void:
	# 子类应该重写这里来实现具体的弹幕或停掉回合逻辑
	pass

func init() -> void:
	battle.battle_event.connect(_on_battle_event)
	action_set(0, "检查", Callable(self , "_on_act_check"))

func _on_act_check() -> void:
	var enemy_name = data.name if data else "null"
	print(enemy_name + " - 检查 (Check)")

## 子类重写此方法以响应战斗事件
func _on_battle_event(_type: Battle.EVENT_TYPE, _event: Variant, _from: Variant) -> void:
	pass

func set_checked(enable: bool) -> void:
	_is_checked = enable

func get_is_checked() -> bool:
	return _is_checked

func action_get_count() -> int:
	return _action_names.size()

func get_actions() -> Array[String]:
	return _action_names

func action_set(slot: int, text: String, callback: Callable = Callable()) -> void:
	if slot > action_get_count():
		return
	if slot == action_get_count():
		_action_names.append(text)
		_action_callbacks.append(callback)
	else:
		_action_names[slot] = text
		_action_callbacks[slot] = callback

func action_get_name(slot: int) -> String:
	if slot >= action_get_count():
		return ""
	return _action_names[slot]

func action_call(slot: int) -> void:
	if slot >= action_get_count():
		return
	if _action_callbacks[slot].is_valid():
		_action_callbacks[slot].call()
