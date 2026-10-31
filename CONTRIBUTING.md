# 多人协作流程

一次任务使用一条分支。每个并行任务使用独立分支和工作目录，不要让多个 AI 同时写同一工作区。

先在 GitHub Issue 或 PR 写明任务负责人、分支、范围和预计会改的关键路径。
同一任务只有一个当前负责人；其他人做独立任务，或先在 Issue/PR 中协调接口。
需要多人并行时，每人/每任务独立 clone 或 worktree，不能共用一份未提交工作区。
README/状态文件由各分支基于最新 main 修改，合并时保留其他已完成任务，不能用旧副本整体覆盖。

## 开始任务

确认没有未提交改动；有的话先辨认作者，提交、另建工作区或让人决定，不能清空它们。

```sh
git status --short
git fetch origin
git switch main
git pull --ff-only
git switch -c feat/your-name-short-task
```

已经在任务分支时，先读取其交接记录和 `git log --oneline --decorate -12`，不要重复创建分支。
AI 的具体接手顺序见 [通信协议](docs/AI_PROTOCOL.md)。

## 完成与上传

1. 运行与变更匹配的测试；没有 Godot 就标明未执行引擎检查。
2. 更新 `docs/PROJECT_STATE.md`；新增交接文件：

```sh
python tools/handoff.py new short-task
# 按提示补全生成的 JSON；不要保留 TODO。
python tools/handoff.py validate
git diff --check
git add <本次任务的文件>
git commit -m "feat(feed): describe the resulting behavior"
git push -u origin HEAD
```

3. 在 GitHub 发起 PR，说明问题、最终行为、交接文件、验证、风险与下一步。
4. 其他开发者或其 AI 先审查实际 diff 与交接，合并到 `main` 后再开始下一个任务。

初始建仓可以直接提交 `main`。之后默认走 PR。这里是团队约定，未宣称服务器已启用强制分支保护。
CI 会检查交接协议和 Python 平衡模拟；**不会冒充运行 Godot 或 Windows 实机测试**。

## 冲突

先 `git fetch origin`，在自己的任务分支合并 `origin/main`，保留双方意图后重新测试。
如果两个功能在设计上互斥，交给项目参与者决定；不要凭某个 AI 的旧聊天记录覆盖另一人的更新。
不要强推共享 `main`，也不要自动丢弃别人的未提交内容。

## 朋友加入

朋友接受 GitHub 邀请后克隆仓库。每人使用自己的 GitHub 登录和提交身份，不共享令牌。
发布文件作为 GitHub Release 附件或单独传输，不提交 EXE/ZIP、引擎缓存或个人存档。
