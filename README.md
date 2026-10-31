# 垃圾王

多人协作开发的 Godot 2D 游戏。当前默认是 **2560×1440 传送工坊切片**：从踩罐起步，安装义手、动力锤与电钻，升级传送门并回收大型家电。经典 Can Stomper v1.1 保留独立入口。

## 开发入口

1. 安装 **Godot 4.7.2 Standard**，使用 GDScript。
2. 克隆此私有仓库，用 Godot 导入根目录的 `project.godot`，按 **F5**。
3. 有 Python 3.10+ 时，也可运行 `python tools/dev.py run`；验证用 `python tools/dev.py test`。
   引擎不在 PATH 时设置 `GODOT_BIN`，或使用 `python tools/dev.py --godot "引擎完整路径" test`。

游戏运行不需要 Python；生成美术的脚本才需要 Pillow。详细操作见 [运行说明](README_RUN.md)。

```sh
git clone https://github.com/t0mAto1104/garbage-king.git
cd garbage-king
```

## 每次换人或换 AI

把这段话发给接手的 AI：

> 这是“垃圾王”游戏仓库。先读取 `AGENTS.md`、`docs/PROJECT_STATE.md` 和 `docs/AI_PROTOCOL.md`。
> 检查当前分支、工作区和 Git 历史，读取与本次任务相关的最新 `docs/handoffs/*.json`，
> 再根据我的需求开发。完成后按协议留下交接文件、真实验证结果和下一步，不覆盖他人的未提交工作。

所有参与者与工具共用同一套版本化文件，聊天记录不作为唯一交接来源。

| 文件 | 用途 |
| --- | --- |
| [AGENTS.md](AGENTS.md) | 所有 AI 的共同入口与游戏约束 |
| [当前项目状态](docs/PROJECT_STATE.md) | 当前需求、架构、接口、限制与下一步 |
| [AI 通信标准协议](docs/AI_PROTOCOL.md) | 拉取、开发、提交、冲突处理和接力规则 |
| [交接记录](docs/handoffs/) | 每次上传的可追溯更新包 |
| [贡献流程](CONTRIBUTING.md) | 多人任务归属、Git 分支与 PR 操作 |

新交接文件：`python tools/handoff.py new your-change-name`。
提交前检查：`python tools/handoff.py validate`。

## 仓库内容

源码、Godot 场景、配置、原始素材、测试与协议一起版本管理；`.godot/`、发布 EXE/ZIP、个人存档和本地日志不进入 Git。
`.gd.uid` 与 PNG 的 `.import` 配置保留，保证两台机器的资源引用和像素导入设置一致。

这是私有项目，没有授予公开分发或开源许可。Godot 和随附组件仍遵守各自许可，见 [声明](THIRD_PARTY_NOTICES.md)。

## 长期产品设计（规划，不等于当前实现）

《垃圾王 / 废品飞升》完整产品概念已整理为 v0.1 文档；首段工坊已按路径 A 实现，剩余长期内容仍是规划。当前实现、验证和后续工作见 [项目状态](docs/PROJECT_STATE.md) 与 [工坊验收](docs/YARD_TEST_REPORT.md)。

- [完整游戏设计 GDD](docs/GDD_FULL_V0_1.md)：故事、玩法、义肢、传送门、章节与升级
- [长期版经济草案](docs/BALANCE_FULL_V0_1.md)：垃圾等级、工具价格、伤害与回收公式
- [美术与音乐](docs/ART_AUDIO_FULL_V0_1.md)：像素画风、动画、资产与音效清单
- [技术演进方案](docs/TECH_PLAN_FULL_V0_1.md)：Godot 结构、兼容、存档与测试
- [原始开发路线图](docs/ROADMAP_FULL_V0_1.md)：阶段、分工、范围与退出条件
- [可执行任务清单](docs/TASKS_FULL_V0_1.md)：按优先级、依赖与验收拆分
- [设计决策与冲突](docs/DECISIONS_FULL_V0_1.md)：已确认、未定、与旧 Demo 的差异
