class_name TestBullet extends Area2D

func _ready() -> void:
	# 设置碰撞层：让子弹在敌人掩码上（或单独的子弹层），能够扫描到玩家层（layer 2）
	# 假设玩家在 layer 2，我们设置 mask 2
	collision_layer = 4 # enemy bullet
	collision_mask = 2 # player soul
	
	# 创建一个 CollisionShape2D
	var shape = CollisionPolygon2D.new()
	# 绘制一个倒三角形或正三角形
	shape.polygon = PackedVector2Array([
		Vector2(0, -10),
		Vector2(-8, 8),
		Vector2(8, 8)
	])
	add_child(shape)
	
func _physics_process(delta: float) -> void:
	# 持续检测重叠，实现：如果玩家一直站在子弹内部，无敌时间一过就会继续扣血
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body is BattleSoulRed:
			body.take_damage(Global.player_data.get("def", 0.0) + 1.0)

func _draw() -> void:
	# 绘制一个白色的三角形
	var points = PackedVector2Array([
		Vector2(0, -10),
		Vector2(-8, 8),
		Vector2(8, 8)
	])
	var colors = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
	draw_polygon(points, colors)

# 每回合自动清理
func retire() -> void:
	queue_free()
