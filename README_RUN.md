# 垃圾王 · 传送工坊

Godot **4.7.2 Standard**、GDScript、纯2D。2560×1440（16:9）设计视口，默认1600×900窗口，轻微像素风。
当前是首段可玩切片，完整长期 GDD 尚未全部实现。

## 运行源码

用 Godot 导入根目录 `project.godot`，按 **F5**。也可运行：

```sh
python tools/dev.py run
```

本地 `启动游戏.command` / Windows `启动开发.bat` 也运行源码，需要 Python3.10+和Godot。
引擎从 PATH、`GODOT_BIN` 或 `--godot` 寻找；macOS还检查桌面与Applications中的Godot.app。
例如 `python tools/dev.py --godot "C:/Tools/Godot/Godot.exe" run`。
游戏本身不需要Python；只有美术生成器需要Pillow。

## 开工

- 鼠标停在废品上连续作业，点击共用冷却；空格作用于悬停物或最早可用物。
- **1–4**切换已拥有的鞋、义手、锤、电钻。切换保留冷却；不同材质有不同工具优势。
- 传送带初始1秒/件，出带后落地、弹跳、滚动到随机位置。未拆完的废品一直堆积。
- 改造页买工具与属性；传送页升级供货、深度、品质、弱点扫描及磁力；档案页记录九类废品与独立自动线。
- 扫描后对准弱点；锤可震碎近邻，电钻连续锁定同件逐步增伤。
- 连拆充能，**F**主动狂拆；解锁磁力后 **R**把附近废品归拢到光标旁。
- 垃圾暴雨、金价日、神秘包裹会改变作业节奏。顶部三枚图标显示电钻、深度II、洗衣机目标。
- **Esc**暂停；失焦也暂停。设置可静音、开关背景音乐、减弱特效或确认重置。小破按钮打开可选故事。
- 工坊目标完成后可继续经营，不强制退出。没有离线补发收益。

## 经典参考

左下“经典 Demo”保留v1.1踩罐玩法，原1280×720设计视口。原型内“返回新工坊”可切回。
经典有三类五阶段罐子、供罐提速、独立自动回收与600秒总结，详情见旧版 `TEST_REPORT.md`。
两种模式后续分别保存，不循环合并钱包。

## 数据和存档

| 模式 | 数值 | 存档 |
| --- | --- | --- |
| 新工坊 | `data/yard_balance.json`，schema1 | `user://yard_save_v3.json`，v3 |
| 经典 | `data/demo_balance.json` | `user://save_v1.json`，内容v2兼容v1 |

Godot应用配置名保留“Can Stomper · 踩扁它！”，以保留旧存档目录；窗口标题独立显示新项目名。
macOS存档位于 `~/Library/Application Support/Godot/app_userdata/Can Stomper · 踩扁它！/`。
新存档不存在时才导入经典进度，保留钱、完整废品堆与对应升级，原文件不改写。
新状态先验证再恢复，原子保存；坏档保留备份并提示。具体迁移、恢复与回退见 `docs/YARD_MIGRATION_V3.md`。
测试使用 `-- --test-mode`，不读写玩家进度。

## 验证与素材

```sh
python tools/dev.py test
python tools/handoff.py validate
```

实际Godot渲染截图（需要图形环境）：

```sh
godot --path . --script tests/capture_yard.gd -- --test-mode
```

新素材与合成音频由 `tools/build_yard_art.py` 确定性生成；经典由 `tools/build_art.py` 生成，均为原创原型。
截图包含用于查看各阶段的开发夹具，不代表真人赚取这些资源的过程。
本轮证据与限制见 `docs/YARD_TEST_REPORT.md`，历史验证见 `TEST_REPORT.md`。

## 发布包状态

本轮没有重新打包。上一级 `发布包/CanStomperDemo_v1.1_Windows_x64.zip` 是经典版，**不包含新工坊**。
旧包可在64位Windows全部解压后运行 `CanStomper.exe`，无需安装Godot/Python；Windows实机兼容性尚待验证。
后续导出时需对新默认入口重新做资源探针与Windows实机检查，不能沿用旧包验证结论。
