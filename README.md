# 魂匣地牢

《魂匣地牢》是一款以魂匣构筑和“瞄准即指挥”为核心的像素地牢游戏。

## 目录

- `game/`：Godot 工程；`data/` 为数据层，`sim/` 为模拟层，`view/` 为表现层，`app/` 为应用层，`assets/` 为资源，`tests/` 为测试。
- `docs/`：设计、架构和任务文档。
- `art/`：美术源文件、色板和来源记录。
- `tools/`：项目工具。

完整目录及职责见 [architecture 第 2 节](docs/architecture.md#2-目录结构)。

## 打开工程

使用 Godot 4.7（本机版本 4.7.2），在项目管理器中点击“导入”，选择 `game/project.godot`，然后打开编辑器。按 F5 运行主场景，即可看到像素缩放测试图。

也可从仓库根目录启动编辑器：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --editor --path game
```

默认逻辑画布为 640×360，窗口为 1920×1080，使用整数倍缩放。

## 运行测试

在仓库根目录执行：

```bash
python3 tools/run_tests.py
```

依次运行 Python 工具测试、分层检查、Godot 无界面导入和 GDScript 测试。全部通过时退出码为 0，最后一行是 `TESTS: N passed, 0 failed`（N > 0）；任一步失败即停止，退出码为 1。

`GODOT_BIN` 可指定 Godot 可执行文件，默认是 `/Applications/Godot.app/Contents/MacOS/Godot`。例如：

```bash
GODOT_BIN=/path/to/Godot python3 tools/run_tests.py
```

失败时先看 `STEP N FAIL` 的原因和此前的输出：断言失败显示 `FAIL 文件::方法`；脚本错误显示错误行及此前最近的 `RUN 文件::方法`；分层违规显示 `文件:行号:规则说明`。即使 Godot 退出码为 0 或打印了通过汇总，脚本错误输出仍会使整次检查失败。

导入限时 120 秒，Godot 测试限时 300 秒。可用 `python3 tools/run_tests.py --timeout 20` 缩短测试阶段限时；超时会结束 Godot 子进程并报告失败。
