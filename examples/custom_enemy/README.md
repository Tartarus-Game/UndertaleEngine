# 可复制的自定义敌人与两种波次

`guide_enemy.tscn` 是继承 `BattleEnemy.tscn` 的独立敌人。复制本目录并修改场景与脚本中的资源路径，即可制作自己的敌人；示例画面沿用引擎占位图。

将场景注册进遭遇，例如：

```gdscript
const GUIDE := preload("res://examples/custom_enemy/guide_enemy.tscn")

func _ready() -> void:
    EncounterManager.encounter_set(123, GUIDE, null, null, "* A guide appeared.")

func start_guide_encounter() -> void:
    EncounterManager.encounter(123)
```

在敌人场景的 `data` 中修改名称、描述、HP、攻击力、经验和金币。`GuideEnemy.gd` 的 `init()` 先调用父类初始化，再通过 `action_set(1, "Encourage", _encourage)` 注册 ACT 回调；回调返回显示文本，第二次鼓励后设置 `spareable = true`。击败敌人获得其 EXP 与 GOLD；饶恕只获得其 GOLD。实际获得的奖励由战斗结算统一发放，不要在 ACT 回调中再手动发放同一笔奖励。

`get_wave_scene(turn)` 按回合交替返回骨头和弹丸场景。每个场景的根节点继承 `BattleWave`；战斗管理器创建新实例、注入 `battle` 和 `source_enemy`，并以战斗的 `turn_duration` 设置本回合长度。两个波次用经过时间和 `while` 调度弹幕：即使一帧跨过多个生成时刻，也不会跳过应生成的弹幕。速度用像素/秒，时间用秒。长帧中补生成的弹幕从当前帧开始运动，不会补算它本应走过的距离。

波次到达 `duration` 后发出 `finished`；多敌人战斗要等所有活跃波次结束。通过 `BattlePatterns` / `battle.spawn_bullet` 加入战斗的弹幕与效果由 `Battle` 在回合结束时清理。波次或敌人自行创建在其他节点下的对象，需要自行在结束或被移除时清理；不要让事件回调继续引用已释放的节点。
