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
