# RK-120 验收记录

2026-10-31，Godot 4.7.2 / macOS Apple M1 / Compatibility OpenGL。
从 main 38af18a 创建 rk-120；依赖合并提交 72d6fdd、8cf9acf、5166dad 均在 main。

复现：`python3 tools/acceptance/rk120_verify.py`。支持任意 cwd、GODOT_BIN；仅 Python 标准库，先 import，每个 Godot 子进程 45 秒超时。非零、引擎 ERROR/SCRIPT ERROR、成功标志缺失/重复都失败。正常唯一最终标志 `RK120: passed`。临时故障分别运行独立图形进程，要求非零且指定故障确实出现，finally 恢复源文件原字节，再跑正向。

## 1. 实际字体和覆盖

两个场景共享局部 debug_ui_theme.tres；RK012 绑定 CanvasLayer 下的 VBoxContainer，RK119 绑定根 Control。未改全局 Theme、project.godot、RK045、字体二进制、许可或 .import。所有正文/按钮/菜单/输入/tooltip/自绘均 12px。

实际 FontFile 为 `res://assets/fonts/fusion-pixel-12px-zh_hans.woff2`。探针逐字符串核对 resource_path、has_char、allow_system_fallback=false、antialiasing=NONE、subpixel_positioning=DISABLED、hinting=NONE、oversampling=1。不是只判断有 Theme，也不依赖系统已安装字体。ReviewCanvas 记录实际 draw_string 使用的 font/size/rect，检查 caption、1×/3×标注、展示靶；不从主题存在与否猜测自绘参数。

[coverage.json](rk120-evidence/coverage.json) 包含各轮去重 texts、码位到字符清单、实际 source/font/size 记录和 failures。正常 review 144 段去重文字 / 221 个码位，player 8 段 / 41 个码位；坏数据轮另收录错误说明、路径及状态。受测字符 has_char 全通过；不宣称覆盖全部 Unicode。PopupMenu 每个条目、LineEdit placeholder/实际输入及各 tooltip 文本均单独检查；实际悬浮生成的 TooltipLabel 也检查字体与几何并截图。

## 2. RK119 操作

两窗口分别冷启动，并遍历全部类别（含 Boss）、idle/run、T1—T4 静态魂匣、三种背景 × 三种材质。实际 GUI 合成鼠标事件命中播放/暂停、单步、首帧、展示靶、画布/主体参考线、盲看/答案、导出；选项使用实际 OptionButton 的 select/item_selected，菜单通过鼠标/键盘展开并确认 visible，覆盖四种倍速文字。原 UI 回归继续保留精确像素和播放行为检查。

输入框通过 InputEventKey.unicode 实际输入“骑士测试”，核对文本与无匹配提示，随后清空并返回玩家默认动作，字体仍有效。导出按钮实际写出 Godot viewport PNG，核对“已导出”状态和绝对路径 tooltip。元数据夹具临时删除骑士 run 第一帧 pivot（保留其身份分类），检查完整文件名、中文错误、停止播放；切换炼金师恢复，finally 还原 JSON 原字节，末尾正向再跑通过。

## 3. RK012 操作

640×360 和 1280×720 下检查初始状态、两个重建按钮和说明。合成鼠标分别命中 +0% / +50% 重建，合成 D 键经 InputCollector → 正式 FixedStepDriver → Sim.step 更新位置和步数，状态文本与实际值一致。没有写 Sim 状态。原 RK012 30/60fps 和键盘/摇杆合成输入回归通过；未用实物鼠标/手柄试玩。

## 4. 图形与布局

实际图形进程导出目录 `/private/tmp/rk120-checks/`。代表 PNG 归档 [rk120-evidence](rk120-evidence/)：两尺寸 cold/menu/target/long/error，中文输入、真实 tooltip，以及两尺寸的 +0%/+50% 移动状态。

1280 窗口使用实际 1280×720 逻辑视口，重新实例化 RK119 场景，未靠放大整界面避开布局检查。Label 检查行数/行高与控件高度，非换行文字检查宽度；按钮检查文字、样式和开关图标所需宽度，同容器兄弟矩形不可相交；底部主要操作/状态及玩家控件不得越出可见视口；实际自绘矩形不得越出画布，已展开菜单检查条目宽度。侧栏允许滚动，错误和完整路径截图先滚动至 Details。原样保留长 ID、PNG/JSON 路径与中文提示，没有删字。

人工查看归档 PNG：中文字形无方框，按钮/状态无截断或互相覆盖；小窗口侧栏滚动可达，长路径换行完整。负向 player_clipped_cold.png 可见状态末尾被裁切，相应检查确实失败。

## 5. 故意改坏

- RK119 取消根主题：报告具体缺字 U+8D44 资（及其他中文），退出 1。
- RK012 取消实际容器主题：报告 U+4F4D 位（及其他中文），退出 1。
- 临时将“展示靶”实际 draw_string 字体替换为 ThemeDB.fallback_font：报告 U+5C55 展等具体中文缺字，退出 1。靶标通过控件开关保持启用，额外要求本帧必须存在靶标实际 draw 记录，避免动画刷新后漏检。
- 临时缩窄状态容器并开启裁切：报告 geometry width，退出 1。

前两项和裁切仅改探针进程内节点；自绘脚本、坏 JSON 都在 finally 恢复精确原字节。全部故障日志与字形清单已归档；全部恢复后新验证和旧回归通过。正式代码没有默认字体自绘入口。

## 6. MCP 与原回归

[MCP 记录](rk120-mcp.json)：分别启动 asset_review_lab / player_movement_lab，读取输出后停止。无脚本错误；RK119 仅有原棋盘整数除法警告，按任务要求未修。

以下命令全部退出 0，详细输出在 rk120-evidence/*.log（归档仅清理行末空白，内容未删改）：

- rk119_verify.py：100 resources / 40 animated / 60 static 精确计数通过。
- rk119_ui_verify.py：原播放、逐帧、倍速、1×/3×像素块零差异、静态品阶/盲看/导出通过。
- rk119_faults.py：rect/pivot/image/json 坏数据及错误逐帧行为探针全部通过，原字节恢复后再回归通过。
- rk075_verify.py：原生源/导出/姿势与两 Boss 大图滚动可达、帧进度及返回小资源复位通过。
- rk012_verify.py：30/60fps、0/+50%、键盘/摇杆与正式驱动链通过。
- rk045_verify.py：字体、56 像素组合、池化/层级/透明度/故障隔离通过；旧只读 RK119/RK012 字体审查均为 []。
- tools/run_tests.py：Python 46 个测试通过，GDScript 153 passed, 0 failed。
- tools/art_check.py：100/100。
- git diff --check 通过。

没有修改任何旧验收探针、断言或误差；无布局/采样适配例外。没有新增 game 内 GDScript，已有 .uid 保持不变；game 外 acceptance 脚本与原验收脚本一致不生成 .uid。

和文档的出入：无；图形验收探针按 RK-120 的明确要求实施。
范围外发现：原棋盘整数除法警告仍在；未改。
