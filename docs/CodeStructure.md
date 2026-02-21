# AI Generated

## 1. 核心架构设计理念

本项目采用 **职责分离 (单一职责原则)** 与 **组件化设计**，将战斗宏观控制逻辑与具体的 UI 渲染节点分拆开来，避免出现庞大的 "God 对象"（如一个脚本包揽所有渲染和逻辑）。

### 1.1 战斗场景核心：`Battle.gd` & `Battle.tscn`
*   **定位**：战斗模式的**全局控制中心 (Controller)**，管理战斗的运转逻辑。
*   **主要职责**：
    *   **状态机维护**：管理当前的菜单层级（是选择动作，还是选择物品，或是敌人回合）。
    *   **输入处理**：统一截获键盘输入（在 `_unhandled_input` 中处理），决定玩家的下一步操作流转。
    *   **信号分发**：一旦战斗状态改变，通过唯一的信号 `battle_event` 向外（尤其是向各 UI 组件）广播事件。
    *   **核心逻辑控制**：计算伤害、管理敌人生成（委托给 `EnemyManager`）、限制心形（Soul）在 UI 选项上的移动坐标或在攻击框内的限制范围。
*   **注意**：`Battle` 自身不应该负责血条颜色的更改、按钮动画帧的切换等具体的视图表现细节。

### 1.2 视图层面板组件：`ScreenBattle.gd` & `ScreenBattle.tscn`
*   **定位**：游戏战斗界面的**局部 HUD (Heads-Up Display) / 视图面板 (View)**。
*   **主要职责**：
    *   渲染在屏幕底部的静态 UI 内容（玩家的名称、LV 等级、HP 数值及红黄相间的血条）。
    *   管理四个主要的交互大按钮：**FIGHT**, **ACT**, **ITEM**, **MERCY** 的动画和高亮显示。
    *   监听来自 `Battle.gd` 的 `battle_event` 信号，在响应诸如 `MENU_CHANGED` 或 `XXX_CHOICE_CHANGED` 等事件时，播放界面音效与刷新自身状态。
*   **关系梳理**：`ScreenBattle` 作为 `Battle.tscn` 中 `UIManager` 的子节点被实例化。它们之间是**主节点发送事件 -> 子节点监听更新**的服务关系。如果将来打算适配移动端触摸屏或其它模式的战斗 UI，只需创建一个新的类似 `Screen` 的场景把它替换即可，这种松耦合保证了极强的扩展性。

### 1.3 战斗调度中心：`BattleManager.gd` (AutoLoad)
*   **定位**：跨整个游戏的**回合制规则裁判团**。
*   **主要职责**：
    *   维持当前是否处于“敌方防守回合 (`is_enemy_turn`)”的最高权限时钟。
    *   **帧同步下发**：一旦进入敌人回合，管理器会接管游戏循环（`_process`），每 50 毫秒向场上全体存活敌人下发时间轴滴答 (`enemy.process_turn(time_elapsed)`)，作为敌人释放独有弹幕的核心驱动力。
    *   **安全调度与善后**：敌人发难结束或调用 `stop_enemy_turn()` 后，它会挂起 1 秒的无弹幕安全缓冲期，随后要求主 UI 进行框体尺寸动画(`await active_battle.restore_box()`) ，结束后再将操作权抛回 `BUTTON` 菜单。
    *   **伤害中心化**：统管 `calculate_and_deal_damage` 等接口，彻底将结算逻辑与具体的怪兽解耦。

### 1.4 数据与逻辑剥离：`EnemyData.gd` (Resource) & `BattleEnemy.gd`
*   **定位**：利用 Godot 原生 `Resource` 系统实现**数据驱动配置**。
*   **逻辑**：
    *   所有的 `BattleEnemy` 节点基类不再写死具体血量、防御、名字。转而开放一个 `@export var data: Resource` 槽位。
    *   通过填入或动态实例化的 `EnemyData` 资源档案，允许在 Inspector 中像做 PPT 一样填入不同杂兵的三围属性。
    *   这种设计大幅缩减了继承敌人类的代码行数，允许代码热重载并一键修改数值（不需要调用 `set_hp` 等样板代码）。

### 1.5 平滑渲染阻断与协程动画 (`await`)
*   传统的轮到敌人直接弹框非常生硬。现在整个回合流转(`BattleManager -> start_enemy_turn() -> Battle.gd -> shrink_box() -> Tween -> await`)是一套基于协程的链条。
*   控制器会在使用物品/行动后自动调用等待动画完成。无论是 `shrink_box` 紧缩成闪避方块，还是 `restore_box` 返回宽屏选项栏，都强绑定了 `await _box_tween.finished`。这保证了逻辑层和视觉层在时序上的绝对同步。

---

## 2. 目录结构规范

经过重构规范后，项目中属于同一个功能模块的脚本与场景资源，原则上遵从以下分布结构：

```text
res://
├── auto_load/                      # 自动加载（AutoLoad 单例）与全局系统
│   ├── AudioManager.gd             # 全局音频播放管理器
│   ├── BattleManager.gd            # 战斗回合全局调度与状态管理器
│   ├── SceneManager.gd             # 场景切换与闪烁过度系统
│   ├── encounter/                  
│   │   └── EncounterManager.gd     # 遭遇战数据管理器
│   ├── items/
│   │   └── Item.gd                 # 物品基类逻辑
│   ├── text/
│   │   └── TextTyper.gd            # 逐字文本打印特效
│   └── Global.gd                   # 玩家状态与存储 (考虑将来拆分 PlayerData)
│
├── battle/                         # 战斗系统根目录
│   ├── Battle.gd / .tscn           # 战斗核心控制器
│   ├── EnemyManager.gd             # 敌人实例化与槽位管理中心
│   ├── BattleEnemySelections.gd    # 敌人目标选择列表管理器
│   ├── BattleEnemyActions.gd       # 敌方动作(ACT)列表管理器
│   │
│   ├── enemy/                      # 实体配置 - 敌人
│   │   ├── EnemyData.gd            # 敌人独立属性资源 (Resource)
│   │   └── BattleEnemy.gd          # 敌人实体基类
│   │
│   ├── soul/                       # 实体配置 - 玩家心形灵魂
│   │   └── BattleSoulRed.gd        # 红心移动逻辑基类
│   │
│   ├── box/                        # UI配置 - 战斗中心对话方框
│   │   └── BattleBox.gd
│   │
│   ├── button/                     # UI配置 - 底部四大按钮
│   │   ├── BattleButtonManager.gd  # 四按钮高亮框架管理器
│   │   └── BattleButton.gd         # 单个交互按钮定义
│   │
│   └── ui/                         # 界面组件大类 (Menu & Panel)
│       ├── ScreenBattle.gd/.tscn   # 战斗底部全家桶主面板
│       ├── BattleItemManager.gd    # 物品库存映射与页数显示管理器
│       ├── EnemyActionSelector.gd  # 带页面滚动的 ACT 技能选项面板
│       ├── EnemyActionSelection.gd # ACT 技能的单行文本节点
│       └── EnemySelector.gd        # 敌人单体目标的名称与血条状态显示项
│
├── font/                           # 字体资源存放区
├── gui/                            # 【框架】包含 UI 导航的各种组件级框架定义 
│   ├── Screen.gd                   
│   └── ScreenManager.gd            
└── resources/                      # 各类美工资产 (图片/音频等)
```

---

## 3. 命名约定 (Naming Conventions)

保持项目一致性的重等重要原则：

### 3.1 标识符规范
1. **类名 / 节点名 (class_name)**：使用 `PascalCase` 大驼峰命名法。
   * 例：`class_name EnemyManager`, `class_name BattleItemManager`。
2. **方法名 / 变量名**：使用 `snake_case` 下划线小写命名法。
   * 例：`enemies`, `player_data_items`, `toggle_fullscreen()`。
3. **常量 / 枚举 (CONST / ENUM)**：使用 `SCREAMING_SNAKE_CASE` 全大写下划线命名法。
   * 例：`SOUL_BUTTON_OFFSET`, `EVENT_TYPE`, `BATTLE_MENU`。
4. **信号名 (Signals)**：遵从 Godot GDScript 的官方标准，必须用名词或动名词小写+下划线，禁止使用大写。
   * 正确：`signal battle_event(type: EVENT_TYPE, event: Variant, from: Variant)`
   * 错误：`signal BattleEvent(...)`

### 3.2 文件名规范
1. **GDScript 脚本与场景**：同 `class_name` 保持完全一致的名称，优先采用 `PascalCase` 制以反映这是某个对象实例。
   * 之前杂乱的 `items.gd`, `EnemySelectorManager.gd` 分别已被纠正为 `BattleItemManager.gd` 与 `BattleEnemySelections.gd`。
2. **音频和美术资源 (*.png, *.wav 等)**：采用 `snake_case` 的前缀格式来做资产分类标辨析，全小写以支持跨平台识别。
   * 例：`snd_squeak.wav`, `spr_fightbt_0.png`。

---

## 4. 消除魔法数字 (No Magic Numbers)

代码中必须尽量杜绝直接将数字坐标、尺寸写入逻辑运算里（例如直接算 `soul.position = Vector2(85, 288 + 32 * slot)`）。
遇到固定参数应直接提取为具有字面意义的**常量 (`const`)** 声明，以提升可读性和维护时的搜索难度。

**示例**：
```gdscript
const SOUL_ITEM_X           := 85.0
const SOUL_ITEM_BASE_Y      := 288.0
const SOUL_ITEM_ROW_HEIGHT  := 32.0

soul.position = Vector2(SOUL_ITEM_X, SOUL_ITEM_BASE_Y + SOUL_ITEM_ROW_HEIGHT * (clamped - battle_item_page))
```
