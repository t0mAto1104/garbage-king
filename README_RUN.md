# 踩扁它！ / Can Stomper

Godot **4.7.2 Standard**、GDScript、纯 2D 的十分钟增量游戏原型。
10 分钟是玩家的目标体验时长。

## Windows 解压运行版

最新发布包：上一级 `发布包/CanStomperDemo_v1.1_Windows_x64.zip`，约 41 MB。
Windows 10/11 的 64 位 Intel/AMD 电脑上，将 ZIP **全部解压**，进入 `CanStomperDemo`，
双击 `CanStomper.exe` 即可。无需安装 Godot 或 Python，请保留同目录的运行数据文件。
包内包括最新持续供罐与精简 UI；资源包检查通过，但尚未在 Windows 实机运行。

## 现在如何运行

1. 用本机 **Godot 4.7.2 Standard** 导入本文件夹的 `project.godot`。
2. 按 **F5** 运行整个项目。
3. 也可以双击本文件夹的 **启动游戏.command**。此快捷脚本直接运行源码，
   Windows 开发机可用 `启动开发.bat`。这些脚本运行源码，不是导出包；需要 Python 3.10+。

命令行（在项目目录）：

```sh
python tools/dev.py run
```

引擎可从 PATH、`GODOT_BIN` 或 `--godot` 指定。macOS 还会查找用户桌面和 Applications 中的 Godot.app。
例如：`python tools/dev.py --godot "C:/Tools/Godot/Godot.exe" run`。

## 操作（1.1 持续供罐）

- 初始传送带每秒送入一罐。罐子离带后下落、弹跳、旋转滚动，在随机位置停稳。
- 未踩扁的罐子会持续积累，不因时间或数量而消失。
- 鼠标进入操作区后变成鞋子，鞋尖停在任意一罐上就会按共用冷却持续踩踏。
- 移开停止。点击与悬停共用冷却，不需要疯狂连点。
- **空格**踩当前悬停罐；未悬停时踩最早到达的可用罐。**Esc**暂停或继续。
  失去窗口焦点自动暂停。
- 左侧“属性升级”购买脚力、回收收益、速度，解锁蓝罐与稀有金罐。
- “自动工坊”首项是**供罐速度**，四次升级：**1.00 → 0.80 → 0.60 → 0.40 → 0.25 秒/罐**，
  费用为 60、220、650、1800 金币。升级保留当前供罐周期进度。
- 独立自动线、自动速度和自动线传送带仍在同页。自动线生产自己的罐子，
  不消耗地面罐堆；鼠标在商店也照常产币。暂停时供罐、滚动和自动线全部停止。
- 玩法/暂停面板可开启“减弱特效与震动”。右上角可静音。
- 左下“重置试玩”需要再次确认。600 秒会显示可关闭的总结，可以继续玩。

## 已完成

原创像素车库背景、红蓝金三类罐子的五个独立形态、鞋尖光标、冲击碎屑与金币提示、
四种合成音效、数据驱动商店与解锁、独立自动生产、存档、损坏存档提示与备份、
暂停、静音、减弱特效、重置和总结。1280×720 设计视口，缩放保持比例，
最小窗口 960×540。界面只保留操作、数量、价格、等级、速度、耐久和门槛；详细说明放在“玩法”面板。

## 数据与存档

- 经济参数唯一来源：`data/demo_balance.json`，启动时加载并验证。
- 核心状态：`scripts/game_state.gd`；供罐/伪物理：`scripts/can_field.gd`；经济公式：`scripts/economy.gd`。
- 存档：沿用 `user://save_v1.json` 文件名，内容版本已升至 **2**，临时文件写入后重命名。
- macOS 默认位于 `~/Library/Application Support/Godot/app_userdata/Can Stomper · 踩扁它！/`。
- 保存完整罐堆，包括种类、位置、旋转、受损状态、运动状态和供罐周期。旧版经济存档自动迁移，
  新增供罐等级从 0 开始。恢复后不补发离线罐子或离线金币；自动线未完成周期仍从零开始。
- 损坏文件备份为 `save_v1.json.corrupt`，不会导致游戏崩溃。
- 场景/截图测试传入 `-- --test-mode`，不读取或写入玩家进度。

## 开发与验证

```sh
python tools/dev.py test
python tools/handoff.py validate
```

`tests/capture.gd` 用实际 Godot 渲染器生成开发验收截图，需要有窗口/图形环境：

```sh
godot --path . --script tests/capture.gd -- --test-mode
```

原创素材生成器 `tools/build_art.py` 使用 Pillow；运行游戏本身不需要 Python 或 Pillow。
素材与音效都是本地确定性生成，没有使用付费素材或外部生成服务。

Windows 打包脚本已支持 `--build`、`--templates`、`--output`，默认从当前用户的 Godot 模板目录取数据，
不依赖其他游戏文件夹。模板哈希收据可用 `--template-receipt` 指定；未指定时不能声称完成官方哈希比对。
`tools/package_macos.py` 仍是未执行的编辑器 runner 方案，可用 `GODOT_APP` 指定本机应用路径，非标准模板导出。

## 当前边界

- 已进行实际 Godot 导入、运行与画面检查；详细结果见 `TEST_REPORT.md`。
- 十分钟成长与稳定性检查使用模拟时间，不是十分钟真人试玩。
- 美术为原创原型，细节与参考概念图存在差距；没有裁切参考图冒充动态素材。
- 系统字体来自当前操作系统，Windows 下中文排版尚未实际运行验证。
- 未发现 `game-dev` CLI，所以未运行 Game Development Studio 的专用采集/封包流程。
- Windows 最新版在 `build/windows-v1.1`，已生成解压运行 ZIP；`build/windows` 是旧文件。
- Mac 包未生成。Windows 资源完整性已检查，但 Windows 实机输入、音频与驱动兼容性仍待验证。
