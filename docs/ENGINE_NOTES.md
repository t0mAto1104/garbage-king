# Godot 4.7.2 实现建议（工程级）

## 预期目录
```
project.godot
scenes/main.tscn
scenes/can.tscn
scenes/shoe_cursor.tscn
scenes/auto_lane.tscn
scenes/ui/sidebar.tscn
scripts/game_state.gd
scripts/data_loader.gd
scripts/can_controller.gd
scripts/shoe_controller.gd
scripts/economy.gd
scripts/upgrade_service.gd
scripts/auto_line.gd
scripts/save_service.gd
data/demo_balance.json
assets/placeholders/*.png
assets/references/*.png
```

## 输入实施重点
- `get_viewport().get_mouse_position()` 定位；专用交互区域（Control MouseFilter / Rect2 判断）明确分离 UI 和游戏区域；场景缩放时应使用同一坐标空间判定。
- 鼠标鞋子显示时，可以在主操作区隐藏系统光标并显示自定义独立 Sprite2D，便于播放踩踏帧/特效；光标离开或窗口失焦后恢复系统鼠标。也可 `Input.set_custom_mouse_cursor()`，但该API提供的是静态系统指针图，动态鞋动画和精确压罐反馈更适合单独 Sprite。
- 鞋 Sprite 使用顶部斜俯视，视觉脚尖为命中点。本包PNG `shoe_cursor_idle.png` 的预估命中位置约为(18,69)，应在 Godot 中调整锚点，使该点对准鼠标。`shoe_cursor_stomp.png` 位置略向下，跳帧前要保持脚尖的世界坐标不飘移。
- 推荐命中判定由 `CanController` 的圆形或椭圆形区域完成，而不是拿鞋整张贴图矩形做碰撞。鼠标停留罐子时周期触发；点击UI时不能波及罐子。

## 单罐生命周期
`SPAWNING → READY → DAMAGED → CRUSHED → REPLACING → SPAWNING`。
HP=0 时立刻将 `payout_claimed` 标记为 true，再处理奖励和异步视觉演出；这能防止额外信号重入重复结算。

## 独立自动线
- `AutoLane` 不能靠触碰玩家鞋子或主罐 HP 触发。
- 读取 `demo_balance.json` 自动间隔与基础红罐奖励。
- 若经济结算和视觉进度条不同步，以经过的游戏时间结算，绘画只是表现；暂停时一起停止。
- 可以在角落同时显示完成数量和收入弹字，让玩家看出“自动产出与手动同时发生”。

## 代码质量
- 价格、奖励、概率函数写成独立方法可单元测试。
- `coins` 使用 int；升级逻辑先检前置/余额，再原子性扣款+变更；发出一次 signal。
- JSON 加载失败时显示清晰错误，不悄悄塞回任意平衡数字。
- 整合与稳定性测试可用本机Godot命令行：`godot --headless --path . --editor --quit`；必须在实际有Godot的环境执行，不得伪报。

## 可测试的画面最低标准
至少有车库结构和水泥地贴图、当前独立罐 Sprite、独立鞋 Cursor、左侧进度/商店、角落自动装置。不能只交付黑底按钮和文字。
