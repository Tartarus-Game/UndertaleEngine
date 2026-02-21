class_name BattleSoulRed extends CharacterBody2D

var speed: float = 150.0

# 玩家战斗数据（直接从 Global 读取）
var player_name: String = "CHARA"

# 无敌时间与闪烁
var invuln_timer: float = 0.0
var blink_timer: float = 0.0
var is_invulnerable: bool = false

func _ready() -> void:
	# 初始化时确保如果有缺省值可以补齐
	if not Global.player_data.has("hp_max") or Global.player_data.hp_max <= 0:
		Global.player_data.hp_max = 20.0
		Global.player_data.hp = 20.0

func take_damage(attack_power: float) -> float:
	if is_invulnerable:
		return 0.0
	
	# 这里可以引入玩家防御力(Global.player_data.def)等公式
	var def = Global.player_data.get("def", 0.0)
	var damage = max(1.0, attack_power - def) # 至少扣1点血
	
	Global.player_data.hp -= damage
	if Global.player_data.hp < 0:
		Global.player_data.hp = 0
	
	print(player_name, " 受到了 ", damage, " 点伤害！当前血量：", Global.player_data.hp, "/", Global.player_data.hp_max)
	
	# 触发 0.5 秒无敌
	is_invulnerable = true
	invuln_timer = 0.5
	
	if Global.player_data.hp <= 0:
		# TODO: 玩家死亡逻辑 (GAME OVER)
		print("GAME OVER")
		
	return damage

func process_turn(time_elapsed: float) -> void:
	# 如果未来玩家在敌方回合也需要周期性结算效果（比如中毒）可以通过此方法
	pass

func _physics_process(delta: float) -> void:
	# 处理无敌时间与闪烁
	if is_invulnerable:
		invuln_timer -= delta
		blink_timer -= delta
		if blink_timer <= 0:
			$sprite.visible = not $sprite.visible
			blink_timer = 0.1 # 每0.1秒闪烁一次
			
		if invuln_timer <= 0:
			is_invulnerable = false
			$sprite.visible = true # 恢复可见
			
	var battle = BattleManager.active_battle
	if not battle:
		return
	if battle.battle_state == Battle.BATTLE_STATE.DEFENDING:
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		velocity = input_dir * speed
		move_and_slide()
