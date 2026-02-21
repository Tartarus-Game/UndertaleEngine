# UndertaleEngine
An UNDERTALE fangame engine. But for Godot.

## 已实现功能
- 全局玩家数据与存档：HP/ATK/DEF、装备与物品槽，支持按存档位保存/读取（`auto_load/Global.gd`）
- 全屏切换：运行时注册 F4 快捷键（`auto_load/Global.gd`）
- 场景管理与淡入淡出：场景切换与过渡（`auto_load/SceneManager.gd`）
- 音频管理：SFX/BGM 双通道，支持音量、变调播放、暂停（`auto_load/audio/AudioManager.gd`）
- 文本打字机：逐字显示、暂停、跳过、音效与回调队列（`auto_load/text/TextTyper.gd`）
- 对话框场景：展开动画 + TextTyper 组件（`dialogue/Dialogue.gd`）
- 对话队列：全局文本/回调 FIFO 管理（`auto_load/DialogueManager.gd`）
- 物品系统基础：Item 基类 + ItemManager 注册/查询 + 示例物品 PROMISE（`auto_load/items/Item.gd`，`auto_load/ItemManager.gd`，`auto_load/items/ItemTest.gd`）
- 遭遇系统：按 ID 读取敌人场景列表并触发战斗切场（`auto_load/encounter/EncounterManager.gd`）
- 战斗系统骨架：菜单状态机与 BattleEvent 信号（`battle/Battle.gd`）
- 战斗 UI：按钮高亮、敌人选择/HP、ACT 选项、物品分页（`battle/UI/*`，`battle/button/*`）
- 敌人系统基础：BattleEnemy 基类与测试敌人（`battle/enemy/`）
- 战斗区域：BattleBox 动态碰撞墙与可调尺寸（`battle/box/`）
- 测试场景：进入后直接触发一次遭遇（`overworld/test_level/`）

## TODO / 待补齐
以下待办来自代码中的空实现与占位逻辑（仓库内无显式 TODO/FIXME 注释）：
- [x] 战斗：FIGHT_AIM / FIGHT_ANIM 分支未实现（`battle/Battle.gd`）
- [x] 战斗：MERCY 按钮未接入 `ui_accept` 逻辑（`battle/Battle.gd`）
- [x] 战斗：BATTLE_STATE 仅有 MENU，缺少敌方回合/结算等状态（`battle/Battle.gd`）
- [x] 战斗：红魂移动与碰撞未实现（`battle/battle_soul/BattleSoulRed.gd`）
- [x] 战斗：BattleManager 空实现（`auto_load/BattleManager.gd`）
- [x] 敌人：`on_battle_menu_changed()` 空实现（`battle/enemy/`）
- 道具：`Item.use/drop/name/info` 空实现；示例道具 `drop()` 为空（`auto_load/items/`）
- 道具：`ItemManager.item_save()` 空实现（`auto_load/ItemManager.gd`）
- 遭遇：`EncounterManager.get_soul()` 空实现（`auto_load/encounter/EncounterManager.gd`）
- 文本：`TextTyper._exit_tree()` 空实现（`auto_load/text/TextTyper.gd`）
- Overworld：OverworldManager 空实现，当前仅测试场景直接触发战斗（`auto_load/OverworldManager.gd`，`overworld/test_level/`）
- 对话：对话框仍为硬编码测试文本（`dialogue/Dialogue.gd`）
- [x] 场景淡出：`SceneManager.change_scene_to_path()` 中 `moudlate` 拼写错误导致淡出无效（`auto_load/SceneManager.gd`）
