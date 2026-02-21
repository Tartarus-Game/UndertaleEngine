extends Node

var active_battle: Battle = null

var is_enemy_turn: bool = false
var turn_timer: float = 0.0
var update_accum: float = 0.0
var ending_turn: bool = false
var end_turn_timer: float = 0.0

func start_enemy_turn() -> void:
	if not active_battle:
		return
	is_enemy_turn = true
	turn_timer = 0.0
	update_accum = 0.0
	ending_turn = false
	end_turn_timer = 0.0
	active_battle.battle_state = Battle.BATTLE_STATE.DEFENDING
	_start_enemy_turn_async()

func _start_enemy_turn_async() -> void:
	# 等待框缩放完毕再开始计算回合
	await active_battle.shrink_box()

func stop_enemy_turn() -> void:
	if not is_enemy_turn or ending_turn:
		return
	ending_turn = true

func _process(delta: float) -> void:
	if not is_enemy_turn or not is_instance_valid(active_battle):
		return
	
	if ending_turn:
		_complete_enemy_turn()
		return
		
	turn_timer += delta
	update_accum += delta
	
	if update_accum >= 0.05:
		update_accum -= 0.05
		if is_instance_valid(active_battle.enemy_manager):
			var enemies = active_battle.enemy_manager.battle_get_enemies()
			for enemy in enemies:
				if is_instance_valid(enemy):
					enemy.process_turn(turn_timer)

func _complete_enemy_turn() -> void:
	ending_turn = false
	is_enemy_turn = false
	await active_battle.restore_box()
	active_battle.battle_state = Battle.BATTLE_STATE.MENU
	active_battle.battle_set_menu(Battle.BATTLE_MENU.BUTTON)

func calculate_and_deal_damage(target: BattleEnemy, attack_power: float) -> float:
	return target.take_damage(attack_power)
