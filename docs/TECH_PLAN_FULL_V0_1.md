# 长期版 Godot 技术方案 v0.1

> 设计提案，不是现有程序实现说明。现有 Can Stomper v1.1 架构、状态及存档契约见 docs/PROJECT_STATE.md。开始实现前先跑现有测试，不可盲目重写已工作的系统。

## 1. 现状（已实装）

- 引擎 Godot 4.7.2 Standard；GDScript，2D；1280×720；
- scripts/game_state.gd 负责经济与升级，scripts/economy.gd 负责纯函数；
- scripts/can_field.gd 负责多罐生成、位置、物理伪模拟、HP、堆积与存档；
- scripts/garage.gd 绘制车库、鞋子光标、罐子与特效；
- scripts/main.gd 为 UI、输入、音效、暂停与存档；
- scripts/data_loader.gd 从 data/demo_balance.json 读取运行时参数；
- scripts/save_service.gd 保存 schema v2，兼容 v1，不补离线收益；
- tests/test_*.gd 与 Python 平衡模拟已存在。
这些不是空工程；先做扩展点识别和回归测试。

## 2. 建议演进而非一次性重构

M0：冻结 v1.1 能玩的玩法、做真实玩家试玩，记录手感与帧率基线。
M1：加独立文档与“新工具原型”实验分支；优先让鼠标工具从鞋变为锤或钻，不拆场景。
M2：将目标扩展成泛型 TrashObject（现有罐对象先以适配方式接入），统一耐久、材质、掉落，不改变旧字段。
M3：增加 ToolController、DamageCalculator、PortalUpgrade、UpgradeCatalog；运行时数值仍从配置读取，新增字段使用版本化迁移和默认值验证。
M4：再判断是否需要一个完整可见人物与侧视机位；此项是最大架构选择，不应与其他升级混在一个 PR。
M5：丰富自动设备、剧情、图鉴、视觉、音效与发行。

## 3. 未来模块责任

| 模块 | 职责 | 对现有代码的关系 |
| --- | --- | --- |
| GameState | 金币、解锁、章节、升级和状态信号 | 扩展现有 scripts/game_state.gd |
| TrashCatalog | 物品定义与掉落配置 | 扩展 scripts/data_loader.gd |
| TrashField | 物体位置、状态、命中、已结算标志 | 保留 scripts/can_field.gd 基线，提取可复用逻辑 |
| ToolController | 装备、主动/被动攻击、CD/输入 | 新模块，逐步替换鞋踩工具配置 |
| DamageCalculator | 材质、弱点、暴击、伤害倍率 | 在 scripts/economy.gd 或纯模块实现 |
| PortalManager | 供货、品质、深度、事件 | 优先组合现有供罐能力 |
| UpgradeManager | 前置、花费、等级、质变效果 | 复用经济购买、避免重复事务 |
| AutoSalvage | 独立自动线与派生速率 | 保持不干预手动罐场 |
| StoryManager | 剧情标志、文本、简短弹窗 | 新模块 |
| Effects/Audio | 池化特效、音效节流与音频总线 | 从 main/garage 逐步分离 |
| SaveService | 完整存档、升级字段迁移 | 保留原子写和 v1/v2 兼容 |

不要为每件垃圾创建一个复杂的物理节点。高密度对象可继续走集中状态与统一绘制，必要时以对象池处理短寿命特效；在性能数据明确后再优化。

## 4. 数据契约和接口原则

运行时参数单一权威来源；不把售价、HP、升级条件散写在 GUI 脚本中。可采用 Godot Resource 或 JSON（当前已有 JSON），**升级数据格式须单独提交迁移设计**。
可选新数据定义：id、name、tier、hp、base_coins、material、quality_weights、visual_ref、fragment_type、modifier_pool、drop_table。所有 ID 稳定、掉落概率和非负价格进行校验。
攻击流程只允许第一次从活跃状态转入 CRUSHED 后触发一次收益；动画、特效、自动线不具备自行入账权限。沿用信号或事件通知驱动 UI，不在每帧全树扫描升级界面。

## 5. 存档与升级兼容

当前 schema v2 已保存完整罐堆、位置、运动、伤害、供罐计时和经济；任何新产品数据版本都需要：
1. 明确当前版本与目标 schema；
2. 建立旧存档迁移策略，保留原有金币/解锁/罐状态；
3. 与运行时默认值区分，防止旧档加载后莫名删除罐；
4. 正常退出、崩溃后恢复、坏档提示、升级后首次加载均需测试；
5. 避免修改 Godot 应用名导致 user:// 存档路径变化。
未做独立迁移测试前，不更改任何运行时数据或存档 schema。独立 Demo 实验可使用隔离存档，不污染真实玩家档。

## 6. 关键性能约束

- 目标 PC 60fps，指标需在真实机器与真实罐数量上测；
- 高频工具反馈音频与数字弹字节流；
- 击中碎片使用有限对象池，不用每个碎片的独立刚体模拟；
- 大件拆解用序列帧与裂纹覆盖模拟，非真实破碎物理；
- 罐子可累积，这是现行产品要求；不能通过悄悄销毁未击毁的罐来规避性能问题；
- 在跨平台窗口中验证像素导入、脚尖 hotspot 与 UI 鼠标恢复。

## 7. 测试与开发顺序

现有文档/测试命令：python tools/dev.py test、python tools/test_balance.py、python tools/handoff.py validate。未来每个新增功能都要增加至少一个可重复测试。测试分为经济纯函数、场地状态/防重复收益、升级解锁、存档迁移、连续运行性能、实际手动试玩。

建议为“鞋→锤→钻”增加 4 项关键测试：攻击 CD 不重入；工具切换不重置金币事务；材质/弱点计算正确；装备更换后保存/恢复一致。真实游戏手感仍必须由人类试玩验证，模拟时长不是有效试玩时长。

## 8. Git 和 AI 协作

按 AGENTS.md 与 docs/AI_PROTOCOL.md：每任务独立分支、交接 JSON、更新 PROJECT_STATE、真实验证/未运行说明、提交 PR 给另一名开发者合并。对文档里的新想法先在 docs/DECISIONS_FULL_V0_1.md 标记未定，未经批准不直接转换成运行时行为。
