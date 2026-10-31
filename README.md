# 垃圾王

多人协作开发的 Godot 2D 游戏。当前可玩版本是 Can Stomper v1.1：鞋尖踩罐、持续供罐、随机滚动、升级与自动回收。

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
