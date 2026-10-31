# 垃圾王：所有 AI 的共同入口

适用于 Codex、Claude、Copilot、Cursor 及其他读取仓库的 AI。这里和版本化文件是共同记忆，不依赖某个聊天会话。

1. 开工先读取 `docs/PROJECT_STATE.md`、`docs/AI_PROTOCOL.md` 与相关 `docs/handoffs/*.json`。
2. 检查分支、未提交内容和 Git diff；保留他人的工作。一次任务一条分支，默认通过 PR 进入 `main`。
3. 上传前新增交接 JSON，更新状态文件，记录真实测试结果、接口/存档变化、限制和下一步。
4. `python tools/handoff.py validate` 检查通信包；`python tools/dev.py test` 运行本地验证。
5. 不能执行的检查写 `not_run` 及原因，不能把模拟时间、资源包检查或旧日志说成新实机测试。
6. 人类最新明确需求优先；初始开发包里的旧单罐描述不能覆盖当前持续供罐需求。

## 游戏工程约束

- Stack: Godot **4.7.2 Standard**, **GDScript only**, 2D-only. Do not add Unity, C#, 3D, Blender, server, LLM API, paid assets.
- Player fantasy: **the mouse pointer IS a shoe** (not a character). Inside the gameplay arena, draw a shoe sprite following the mouse, with toe/hotspot aligned exactly to the hit point. Never draw a leg or person. Over UI keep ordinary pointer so purchases remain accurate.
- Reference layout: fixed camera, light pixel-art garage/concrete floor, central arena occupies ~76% width, upgrades on left ~24%. No moving 3D camera. Not a scrolling platformer.
- All runtime balance values from `res://data/demo_balance.json`, loaded once with validation and usable fallback errors. DO NOT hardcode balance prices, can HP, rewards or unlock thresholds into GUI scripts.
- Current user requirements override the original single-can concept: supply one can per second on the initial conveyor; each falls, bounces and rolls to a random resting location. Intact/partly damaged cans accumulate without despawning. The supply-speed upgrade is independent of automated processing.
- Interaction: while shoe hotspot overlaps any floor can, repeat stomp at the shared cooldown; clicking shares that cooldown. Use its persistent serial and rotated visual hitbox, not a fixed central target. Space targets a hovered can or the oldest available floor can.
- Core loop state transitions are deterministic and testable. Progress and coin rewards only on transition to `CRUSHED`; protect against duplicate reward from animation callbacks, particles, re-entrant input or load.
- 2D pseudo-physics: switch among five distinct can appearance frames. Tween is ONLY secondary impact deformation (x widen, y squash, quick bounce). No real-time mesh simulation or 3D models. VFX pools limited.
- Auto line is INDEPENDENT of manual center can; its own timer, small visible conveyor progress, separate rewards, no cursor required. Must continue if player moves mouse to UI.
- Gameplay economy pure functions and engine time separated from visual animation. Use signals (`coins_changed`, `can_state_changed`, `upgrade_purchased`, `unlock_changed`, etc.) rather than polling entire UI excessively.
- Save normalized economy and complete field state (positions, damage, movement, supply progress) under `user://`. Schema v2 keeps all accumulated cans and migrates v1 economy saves. No offline catch-up. Explicit Reset Demo button with confirmation.
- UI preference: avoid unnecessary secondary labels and descriptions. Show functional prices, levels, counts, rates, HP and unlock requirements; let the conveyor, layout and animation explain the mechanics. Keep detailed instructions in the explicit help panel.
- User authorized Windows packaging on 2026-10-26. Current release: `build/windows-v1.1/` and `../发布包/CanStomperDemo_v1.1_Windows_x64.zip`. The earlier `build/windows/` build remains stale. Do not create a macOS package unless requested.
- Initial MVP no offline income. Save and continue when game closed; pause game time when paused, do not award offline coins.
- All generated art placeholders should be ORIGINAL. Bundled concept references are guide images, NOT sprite atlases. Do not copy logos and UI verbatim from reference commercial games.
- Deliver code, scenes, audio placeholders if practical, CLI test scripts, and `README_RUN.md` explaining how to run. Run Godot import/headless parse, and tests if executable available. Never report test success unless command executed.
- Implement in order P0-P7. Stop at each phase if explicitly requested; report changed files, tests, blockers, manual QA checks.
