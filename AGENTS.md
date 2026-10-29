# AGENTS.md

本文件写给在本仓库工作的 Codex。开始任何任务前先读完。

## 你的角色
你负责《魂匣地牢》的**开发、测试和美术出图**。项目经理（Claude）给你写任务说明并验收你的提交；项目负责人（用户）做最终决定。

## 必读文档
| 文档 | 内容 | 什么时候读 |
|---|---|---|
| `docs/architecture.md` | 分层、目录、编码和测试规范、提交格式 | 每个任务开始前 |
| `docs/backlog.md` | 任务清单、依赖、验收标准 | 每个任务开始前，找到你的任务编号 |
| `docs/tasks/rk-XXX.md` | 单个任务的详细说明 | 有就读，以它为准 |
| `docs/design-reference.md` | GDD，玩法规则和数值 | 任务涉及玩法时，读任务里引用的章节 |
| `docs/style-bible.md` | 美术规范 | 做画面、出图时 |

文档之间冲突时：任务说明 > backlog > architecture > GDD。发现冲突就在汇报里写出来，不要自己选一个悄悄做。

## 工作流程
1. 确认任务的依赖都已合并到 `main`（`git log main --oneline` 里能看到）
2. 从最新的 `main` 拉分支，分支名是小写任务编号：`git switch -c rk-002 main`
3. 只做这个任务范围内的事。看到别的问题记下来，写进汇报，不要顺手改
4. 运行测试（RK-003 完成前，按任务说明里的检查步骤）：
   ```bash
   python3 tools/run_tests.py
   ```
5. 按 `docs/architecture.md` 第 10 节的格式提交到任务分支
6. 按下面的格式汇报

## 禁止
- 提交到 `main`、合并分支、改写已有的提交历史、`git push --force`
- 修改 `docs/` 下的文件，任务说明明确要求的除外
- 删除或修改 `art/ai_raw/` 里的文件
- 把令牌、密钥写进任何文件（PixelLab 令牌只放在本机环境变量里）
- 为了让测试通过而删掉测试、放宽断言或跳过检查

## 环境
- Godot：`/Applications/Godot.app/Contents/MacOS/Godot`（4.7.2），也可用环境变量 `GODOT_BIN` 指定
- 无界面运行前要先导入：`"$GODOT_BIN" --headless --path game --import`
- Godot 脚本出错时进程可能不退出。自己运行 Godot 时一定加超时（macOS 没有 `timeout` 命令，用 Python 的 `subprocess.run(..., timeout=...)`）
- Python 3.9，只用标准库

## 汇报格式
任务做完（或卡住）时，回复：

```
任务：RK-XXX
分支：rk-xxx
状态：完成 / 卡住
验收标准逐条结果：
1. <backlog 里的第 1 条> —— 通过 / 未通过，依据（测试名或检查步骤和输出）
2. ...
和文档的出入：<没有就写"无">
发现的其他问题：<没有就写"无">
```
