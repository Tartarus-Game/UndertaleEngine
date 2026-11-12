# 参考工程功能对照（进行中）

此表记录已核对的源码或文档位置，不表示四个工程的功能已经全部盘点完，也不保证 Godot 版本与原项目逐帧一致。参考代码为 GameMaker；本项目的实现独立编写，速度使用像素/秒、角速度使用弧度/秒、时长使用秒。`基础` 表示有可运行版本但仍有差异，`待实现` 表示当前尚无对应功能。

| 参考工程与功能 | 源码依据 | 本项目状态与缺口 |
| --- | --- | --- |
| TML233：战斗、主世界和多语言 | [README](https://github.com/TML233/UndertaleEngine/blob/e3d9ad6e72236ff54358ecbd11ddae03b9c584d3/README.md)、[红魂移动](https://github.com/TML233/UndertaleEngine/blob/e3d9ad6e72236ff54358ecbd11ddae03b9c584d3/objects/battle_soul_red/Step_0.gml) | 基础：有战斗、主世界、语言切换及红魂；完整内容、文本覆盖和原版行为仍须核对。 |
| UndergameEngine：擦弹与 TP | [擦弹奖励](https://github.com/SheepYhangCN/UndergameEngine/blob/31642e9455be83aeb247380ac636fe303e636a4e/objects/battle_soul_graze/Other_10.gml)、[弹幕擦弹触发](https://github.com/SheepYhangCN/UndergameEngine/blob/31642e9455be83aeb247380ac636fe303e636a4e/objects/battle_bullet/Step_0.gml) | 基础：可选擦弹区域、冷却、TP 显示、上限与花费接口；高速擦弹和自定义多边形弹幕尚未连续检测。 |
| UndergameEngine：友谊颗粒 | [默认参数](https://github.com/SheepYhangCN/UndergameEngine/blob/31642e9455be83aeb247380ac636fe303e636a4e/objects/battle_bullet_friendlypellet/Create_0.gml)、[入场动画与计时](https://github.com/SheepYhangCN/UndergameEngine/blob/31642e9455be83aeb247380ac636fe303e636a4e/objects/battle_bullet_friendlypellet/Alarm_2.gml)、[发射](https://github.com/SheepYhangCN/UndergameEngine/blob/31642e9455be83aeb247380ac636fe303e636a4e/objects/battle_bullet_friendlypellet/Alarm_1.gml) | 基础：实现顺序入场、停顿、发射；原工程的计时可与入场并行，且有回弹选项，尚未复现。 |
| UndergameEngine：单发枪和瞄准提示 | [参数](https://github.com/SheepYhangCN/UndergameEngine/blob/31642e9455be83aeb247380ac636fe303e636a4e/objects/battle_bullet_gun/Create_0.gml)、[蓄力](https://github.com/SheepYhangCN/UndergameEngine/blob/31642e9455be83aeb247380ac636fe303e636a4e/objects/battle_bullet_gun/Alarm_1.gml)、[发射](https://github.com/SheepYhangCN/UndergameEngine/blob/31642e9455be83aeb247380ac636fe303e636a4e/objects/battle_bullet_gun/Alarm_2.gml) | 基础：可配置汇聚标记、开火时长、颜色、音效和 `fired` 信号；目前使用程序化圆形判定与视觉效果，并非原版精灵和精确判定。 |
| UndergameEngine：骨墙、炮台、平台等生成接口 | [中文组件说明](https://github.com/SheepYhangCN/UndergameEngine/blob/31642e9455be83aeb247380ac636fe303e636a4e/README_sChinese.md) | 基础：骨、骨墙、骨环、炮台、平台、光束和波纹已有程序化组件；完整参数和原版动画尚未对齐。 |
| Zhazha：多边形战斗框 | [多边形绘制](https://github.com/onezhazha233/Undertale-Engine-modded-by-Zhazha/blob/63f9981a425d5cbfbe795a35a0e96709f6dd39d7/objects/battle_board_polygon/Draw_0.gml) | 基础：支持多边形碰撞边界与遮罩；凹形、变换、描边和蓝魂交互还需验证和完善。 |
| Swapfell remake：旋转骨环 | [骨环更新](https://github.com/onezhazha233/swapfell-remake-project/blob/8705a74a7f012c62dbc4d5daa453bc8c0196f143/objects/battle_bonering/Step_0.gml) | 基础：可生成旋转骨环；旋转导致的连续碰撞和动画配置未完成。 |
| Swapfell remake：骨锥 | [默认参数](https://github.com/onezhazha233/swapfell-remake-project/blob/8705a74a7f012c62dbc4d5daa453bc8c0196f143/objects/battle_bonecone/Create_0.gml)、[等待、旋转、加速](https://github.com/onezhazha233/swapfell-remake-project/blob/8705a74a7f012c62dbc4d5daa453bc8c0196f143/objects/battle_bonecone/Step_0.gml) | 待实现：蓄力后转向并加速的骨锥。 |

其他对象和脚本尚待逐项确认；不同参考工程中名字相同的对象也可能有不同语义。对照时同时检查具体行为、参数、许可和资源来源，避免把演示用占位效果当成完整实现。
