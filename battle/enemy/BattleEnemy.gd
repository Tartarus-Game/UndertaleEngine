class_name BattleEnemy extends Node2D

signal defeated

var battle: Battle
var _is_dead := false

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

func is_dead() -> bool:
	return _is_dead

## 敌人退役（HP <= 0 时调用）
func retire() -> void:
	if _is_dead:
		return
	_is_dead = true
	# 断开信号
	if battle and battle.battle_event.is_connected(_on_battle_event):
		battle.battle_event.disconnect(_on_battle_event)
	# 淡出动画
	var tw = create_tween()
	tw.tween_property(self , "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		defeated.emit()
		queue_free()
	)

func process_turn(time_elapsed: float) -> void:
	# 子类应该重写这里来实现具体的弹幕或停掉回合逻辑
	pass

func init() -> void:
	if battle:
		battle.battle_event.connect(_on_battle_event)
	else:
		push_warning("BattleEnemy.init(): battle is null, cannot connect signals")
	action_set(0, "检查", Callable(self , "_on_act_check"))

func _on_act_check() -> void:
	var enemy_name = data.name if data else "null"
	var hp = data.hp if data else 0
	var hp_max = data.hp_max if data else 0
	var def = data.defense if data else 0
	
	var text = "%s - HP %d/%d DEF %d\n* 这是一个为了测试而生的沙包。" % [enemy_name, hp, hp_max, def]
	
	if battle:
		battle.start_dialogue(text, func():
			# 文本阅读完毕后，进入通常的敌方回合
			battle.battle_set_menu(Battle.BATTLE_MENU.BUTTON)
			BattleManager.start_enemy_turn()
		)
	else:
		print("检查: ", text)

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
