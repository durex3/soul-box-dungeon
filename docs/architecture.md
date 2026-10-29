# 《魂匣地牢》项目架构与开发规范

> 版本：v0.1（2026-10-29）
> 依据：`docs/design-reference.md`（GDD v0.4）、`docs/style-bible.md`（v0.2）、`docs/backlog.md`
> 读者：开发和测试（GPT）按本文件写代码，项目经理（Claude）按第 11 节验收
> 本文件和 GDD 冲突时，玩法以 GDD 为准，代码结构以本文件为准。要改本文件，先提出，由项目负责人拍板

---

## 1. 架构原则

| 原则 | 含义 | 对应需求 |
|---|---|---|
| 逻辑和表现分离 | 所有玩法规则写在不依赖节点的模拟层里，表现层只负责画出来、播出来 | 无界面测试（GDD 18 节）、平衡模拟（RK-082） |
| 确定性 | 同一个种子、同一串输入，必定得到同一局结果 | 每日挑战、回放（RK-081）、问题复现 |
| 数据驱动 | 数值全部放在数据表里，代码里不写玩法数字 | 打磨期频繁调数值（RK-079） |
| 先测试后接画面 | 每个规则先在模拟层用测试跑通，再做节点和表现 | 验收时以测试结果为主要依据 |

---

## 2. 目录结构

```
soul-box-dungeon/
├── docs/                    文档
├── art/                     美术源文件和来源记录（style-bible 13.2 节）
├── tools/                   Python 工具：色板、美术检查、测试运行器、层级检查
└── game/                    Godot 工程根目录（project.godot 所在）
    ├── data/                数据层：数值表和校验
    ├── sim/                 模拟层：全部玩法规则，不依赖节点
    │   ├── core/            Sim 入口、RunState、InputFrame、Command、SimEvent、随机流、空间哈希
    │   ├── combat/          伤害、属性、受击、控制效果、魂印、共鸣
    │   ├── entities/        玩家、敌人、弹体、拾取物的数据和行为
    │   ├── soulbox/         魂匣、合成、羁绊、进化
    │   ├── progression/     经验、升级四选一
    │   ├── economy/         魂晶、商店、权重、宝箱
    │   └── flow/            波次、刷怪、Boss、单局流程
    ├── view/                表现层：场景、节点脚本、特效、界面
    │   ├── battle/          战斗场景、实体节点、节点对象池、镜头、输入采集
    │   ├── ui/              HUD、商店、升级、暂停、结算
    │   └── fx/              shader 和程序绘制的特效
    ├── app/                 应用层：启动、场景切换、存档、设置、单局日志、调试面板
    ├── assets/              导入的资源：sprites/、fonts/、audio/
    └── tests/               测试，目录结构和 sim/、data/ 对应
        ├── lib/             测试基类和运行入口
        ├── data/
        └── sim/
```

- 场景文件 `.tscn` 和它的脚本放在同一个目录，文件名相同
- `build/` 放导出的可执行文件，不进版本库

---

## 3. 分层与依赖

```
app ──→ view ──→ sim ──→ data
```

依赖只能从左往右，`app` 也可以直接用 `sim` 和 `data`。下层不知道上层的存在。

| 层 | 目录 | 可以依赖 | 禁止 |
|---|---|---|---|
| 数据层 | `data/` | 无 | 引用其他层；运行时修改数据 |
| 模拟层 | `sim/` | `data/` | 继承或引用 `Node` 及其子类；使用 `Input`、`Time`、`OS`、`FileAccess`、`get_tree()`、信号；调用全局随机函数 `randf()`、`randi()`、`randomize()` 等；引用 `res://view/`、`res://app/` |
| 表现层 | `view/` | `sim/`、`data/` | 修改模拟层状态（只能通过 `Sim.step()` 和 `Sim.apply()`）；在表现层判定伤害、掉落、概率 |
| 应用层 | `app/` | 全部 | 写玩法规则 |

- 模拟层的类继承 `RefCounted`，或者是只含 `static func` 的类
- 这些规则由 `tools/lint_layers.py` 检查，`tools/run_tests.py` 会先跑它（第 9.2 节）

---

## 4. 模拟层设计

### 4.1 入口和数据流

模拟层只有一个入口对象 `Sim`，外部只通过下面三个方法和它交互：

| 方法 | 用途 | 何时调用 |
|---|---|---|
| `Sim.new(seed: int, character_id: StringName)` | 开一局 | 单局开始 |
| `step(input: InputFrame) -> Array[SimEvent]` | 推进 1 个逻辑帧 | 战斗中，每秒 60 次 |
| `apply(cmd: Command) -> Array[SimEvent]` | 执行一次非战斗操作 | 商店、升级、熔炉、开始下一波 |

一局的全部状态放在 `sim.state`（`RunState`）里。表现层可以读它，不能写它。

```
玩家输入 ─→ InputFrame ─→ Sim.step()  ─→ RunState 更新
                                     └─→ Array[SimEvent] ─→ 表现层播放特效、音效
界面操作 ─→ Command ────→ Sim.apply() ─→ （同上）
```

### 4.2 固定逻辑帧

- 逻辑帧率固定为 60 Hz，常量 `Sim.DT = 1.0 / 60.0`。模拟层的计时都按 `Sim.DT` 累加，不接收渲染帧的 `delta`
- 驱动循环写在表现层的战斗场景里：

```gdscript
const MAX_FRAME_TIME: float = 0.25  # 卡顿时最多补 15 帧，避免越补越卡

var _accum: float = 0.0

func _process(delta: float) -> void:
	_accum += minf(delta, MAX_FRAME_TIME)
	while _accum >= Sim.DT:
		var events: Array[SimEvent] = sim.step(input_collector.sample())
		battle_view.handle_events(events)
		_accum -= Sim.DT
	battle_view.sync(sim.state)
```

- 商店、升级界面打开时不调用 `step()`，游戏自然暂停

### 4.3 InputFrame 和 Command

- `InputFrame`：一帧的玩家输入。字段为移动方向、瞄准点（世界坐标）、开火、切换武器、技能、释放共鸣。辅助瞄准在表现层采集输入时算好，结果写进瞄准点
- `Command`：一次界面操作，例如购买第 n 格、锁定、刷新、合成、出售、选升级、进化、开始下一波。魂晶不够等不合法的操作返回失败事件，不报错
- 回放只需要记录：种子、角色、每帧的 `InputFrame`（只存有变化的帧）、每条 `Command` 和它所在的帧号

### 4.4 SimEvent

- 模拟层不用信号，也不回调表现层。每次 `step()`、`apply()` 把这一帧发生的事作为事件列表返回
- 事件引用实体时用整数 `entity_id`，不传对象。表现层用 `entity_id` 找到对应的节点
- 事件类型用枚举 `SimEvent.Kind`，例如 `SPAWNED`、`DAMAGED`、`DIED`、`SIGIL_APPLIED`、`RESONANCE_FIRED`、`LEVEL_UP`、`WAVE_ENDED`、`COMMAND_FAILED`
- 测试直接检查返回的事件，不用接节点

### 4.5 随机流

- 每局一个种子，派生出 4 个互不影响的子随机流：刷怪、商店、掉落、升级（GDD 18 节）
- 子流用 `RandomNumberGenerator`，种子由主种子和流名称算出，写在 `sim/core/run_rng.gd`
- 新的随机用途要新建子流，不借用别的流。否则改了商店逻辑，刷怪结果也会跟着变

### 4.6 确定性规则

1. 模拟层只用 `RunRng` 的子流取随机数
2. 不读系统时间、帧号、窗口大小和设置项。影响玩法的选项（比如危险等级）在开局时作为参数传入
3. 实体列表用数组，按 `entity_id` 从小到大更新。要删除的实体在帧末统一删，不在遍历中删
4. `Dictionary` 只用在键的插入顺序确定的地方
5. 同一份代码、同一个种子、同一串输入，必须得到同一个 `RunState`。从 RK-081 起用回放测试保证（第 9.5 节）

### 4.7 性能约定

- 碰撞和范围查询都走 `sim/core/spatial_hash.gd`，不用 Godot 物理和 `Area2D`
- 实体对外只暴露 `entity_id` 和只读字段。RK-010 压测不达标时，模拟层内部改成"每个字段一个数组"的存储方式，表现层改用 `MultiMeshInstance2D`，两层之间的接口不变
- 压测目标见 GDD 18 节：GTX 1060 上 300 个敌人加 1500 个弹体，平均 60 fps

---

## 5. 数据层规范

- 每张表一个文件，例如 `data/soul_table.gd`，`class_name SoulTable`，只包含 `const ROWS` 和静态校验函数
- RK-004 的 6 张表之外，另建 `data/balance.gd`，存放公式系数，比如生命成长 0.22、合成倍率 2.2
- 每行是一个 `Dictionary`，必填 `id`（`StringName`，小写字母、数字、下划线）和 `name_cn`
- 引用其他表的字段名以 `_id` 结尾，例如 `evolve_relic_id`
- 每组数据注明 GDD 出处：

```gdscript
class_name SoulTable
extends RefCounted

const ROWS: Array[Dictionary] = [
	# GDD 7.2 节
	{ "id": &"fireball", "name_cn": "火球匣", "tags": [&"fire"], "damage_t1": 8.0, "cooldown": 1.2,
	  "evolve_relic_id": &"dragon_heart", "evolve_to_id": &"meteor" },
]

## 返回错误列表，空列表表示通过。rows 作为参数传入，测试可以传故意写错的数据
static func validate(rows: Array[Dictionary]) -> PackedStringArray:
	var errors: PackedStringArray = []
	var seen: Dictionary = {}
	for i: int in rows.size():
		var row: Dictionary = rows[i]
		if not row.has("id"):
			errors.append("SoulTable 第 %d 行缺少 id" % i)
			continue
		if seen.has(row["id"]):
			errors.append("SoulTable id 重复：%s" % row["id"])
		seen[row["id"]] = true
	return errors
```

- 跨表引用由 `data/data_check.gd` 的 `validate_all()` 统一检查
- 不用 `assert` 做数据校验。`assert` 在导出的正式版本里会被去掉，测试也拿不到它的结果
- 启动时由应用层调用 `validate_all()`，有错误就显示错误列表并停止进入游戏

---

## 6. 表现层规范

- 节点只读 `sim.state`、处理 `SimEvent`，不改状态，不做判定
- 每个实体节点记住自己的 `entity_id`。`battle_view` 维护 `entity_id → 节点` 的映射，收到 `DIED` 事件后把节点还给对象池
- 弹体、伤害数字、拾取物的节点用对象池（RK-008），池放在 `view/battle/`
- 画面规格全部按 style-bible：保留色、绘制层级、像素对齐、特效亮度上限
- 输入只在 `view/battle/input_collector.gd` 读取，其他节点不调用 `Input`

## 7. 应用层规范

- 负责：启动时校验数据、场景切换、存档（`user://save.json`）、设置（`user://settings.json`）、单局日志（`user://runs/`）、调试面板
- 存档和日志都带 `version` 字段。读取失败时备份旧文件并提示，不崩溃
- 调试面板只在调试版本加载（`OS.is_debug_build()`），正式导出时选 release，面板没有入口

---

## 8. 编码规范

### 8.1 工程设置（RK-002 时配好）
- 开启强制类型：在 `project.godot` 的 `[debug]` 段写 `gdscript/warnings/untyped_declaration=2`。之后变量、参数、返回值缺类型时直接无法运行
- 类型写法二选一：显式类型 `var hp: float = 100.0`，或推断类型 `var hp := 100.0`

### 8.2 风格
按 Godot 官方 GDScript 风格指南，另外约定：

| 对象 | 写法 | 例子 |
|---|---|---|
| 文件、目录 | 小写加下划线 | `soul_box.gd`、`view/battle/` |
| 类名 | 大驼峰，和文件名对应 | `SoulBox` |
| 函数、变量 | 小写加下划线 | `apply_damage`、`max_health` |
| 常量、枚举值 | 全大写加下划线 | `MAX_SIGILS`、`Kind.DIED` |
| 私有成员 | 下划线开头 | `_accum` |
| 数据 id | `StringName`，小写加下划线 | `&"skull_rat"` |

- 缩进用 Tab
- 一个文件只放一个主要的类，超过 400 行就拆
- 公开函数用 `##` 写一句说明。注释写"为什么"，不复述代码

### 8.3 数字
- 玩法数值（伤害、概率、时长、价格、系数）一律从数据层读，不写在代码里
- 可以写在代码里的数字：0、1、-1、数组下标、单位换算（如 1 格 = 16 像素，定义成常量 `TILE_PX`）
- 和 GDD 有出入时以数据表为准，在提交说明里写明，由项目经理决定是否回改 GDD

### 8.4 错误处理
- 程序错误（不该发生的情况）：调用 `push_error()` 并返回安全值。测试运行时出现这类错误，整次测试判为失败（第 9.2 节）
- 玩家操作不合法（魂晶不够、栏位已满）：不算错误，返回 `COMMAND_FAILED` 事件，由界面提示

---

## 9. 测试规范

### 9.1 测试文件
- 放在 `game/tests/`，目录和 `sim/`、`data/` 对应。例如 `sim/combat/damage.gd` 的测试是 `tests/sim/combat/test_damage.gd`
- 测试文件继承 `tests/lib/gd_test.gd`（`class_name GdTest`）。运行入口自动找出 `test_` 开头的文件和方法，不用手动注册
- 一个测试方法只测一件事，名字说明场景：

```gdscript
extends GdTest

func test_negative_armor_is_linear() -> void:
	# GDD 4.5 节：护甲 < 0 时，受到伤害 = 敌人伤害 × (1 + |护甲| × 5%)
	near(Damage.taken(100.0, -10), 150.0)

func test_armor_floor_is_minus_20() -> void:
	near(Damage.taken(100.0, -25), Damage.taken(100.0, -20))
```

- `GdTest` 提供 `eq()`、`near()`、`ok()` 等断言。断言失败只记录，不中断，同一方法里后面的断言照常执行

### 9.2 运行
只用一条命令：

```bash
python3 tools/run_tests.py
```

它依次执行：
1. `python3 -m unittest discover -s tools`：工具脚本的测试
2. `python3 tools/lint_layers.py`：检查第 3 节的层级规则
3. `godot --headless --path game --import`：生成类名缓存。不做这一步，`class_name` 声明的类在无界面模式下找不到
4. `godot --headless --path game -s res://tests/lib/run_tests.gd`：运行全部测试，限时 300 秒

下面任一情况都判为失败：退出码不为 0；超时；第 4 步的输出里出现 `SCRIPT ERROR` 或 `ERROR:`；最后一行不是 `TESTS: <通过数> passed, 0 failed`。

Godot 路径从环境变量 `GODOT_BIN` 读取，默认为 `/Applications/Godot.app/Contents/MacOS/Godot`。

### 9.3 覆盖要求
| 类型 | 要求 |
|---|---|
| 公式和纯函数 | 覆盖正常值和边界值，GDD 里写了的数值逐条核对 |
| 系统（魂匣、商店、升级等） | 每个公开方法至少 1 个用例，不合法的操作也要测 |
| 概率 | 固定种子抽 10000 次，各项占比和目标相差不超过 1.5 个百分点 |
| 验收标准 | backlog 里写"测试"的每一条，都要有对应的测试方法，并在提交说明里列出方法名 |
| 表现层 | 不写自动测试。提交说明写手动检查步骤，画面相关的附截图 |

### 9.4 测试的写法
- 不依赖运行顺序，也不依赖其他测试留下的状态。每个测试自己创建 `Sim` 或系统对象
- 随机一律用固定种子
- 全部测试在 60 秒内跑完。概率测试的样本数够用即可

### 9.5 回放回归测试（RK-081 起）
- 在 `tests/replays/` 存几局的种子和输入记录，以及终局 `RunState` 的哈希
- 测试重放这些记录，哈希必须一致
- 调整数值后哈希会变：提交时更新哈希，并在 `docs/balance-log.md` 写明原因。没改数值哈希却变了，说明确定性被破坏，按缺陷处理

---

## 10. 分支与提交

- `main` 始终能通过 `python3 tools/run_tests.py`
- 每个任务从 `main` 拉一个分支，名字是小写的任务编号，例如 `rk-015`。一个分支只做一个任务
- 分支里可以提交多次，最后一次提交按这个格式写说明：

```
RK-015: 伤害公式

做了什么：
- sim/combat/damage.gd：最终伤害、受到伤害（护甲分正负两段）
怎么验证：
- python3 tools/run_tests.py 通过
- 对应验收标准的测试：test_negative_armor_is_linear、test_armor_floor_is_minus_20
与 GDD 的出入：无
```

- 提交 Godot 生成的 `.import` 和 `.uid` 文件，不提交 `.godot/` 目录
- 开发只提交到任务分支。验收通过后由项目经理合并到 `main`（`git merge --no-ff`），再删除任务分支
- 不改和任务无关的文件。顺手发现的问题告诉项目经理，由项目经理开新任务

---

## 11. 代码验收清单

项目经理逐项检查，任一项不满足就退回，并写明条目编号：

1. 依赖的任务都已合并到 `main`
2. 在任务分支上运行 `python3 tools/run_tests.py`，结果通过
3. backlog 里该任务的每条验收标准，都有对应的测试或手动检查步骤，结果符合
4. 改动只涉及本任务，分层正确（第 3 节）
5. 玩法数值来自数据层（第 8.3 节）
6. 新增的公开函数有类型和 `##` 说明
7. 提交说明符合第 10 节的格式，和 GDD 的出入都写明了

---

## 12. 已验证的环境事实

2026-10-29 在本机 Godot 4.7.2 上实测：

| 现象 | 结论 |
|---|---|
| 无界面模式用 `-s` 运行脚本，调用 `quit(3)` 后进程退出码为 3 | 测试入口可以用退出码报告结果 |
| 没先执行 `--import` 时，引用 `class_name` 声明的类会报"未声明" | 运行器必须先导入（第 9.2 节第 3 步） |
| 设置 `gdscript/warnings/untyped_declaration=2` 后，缺类型的参数、变量、返回值都报解析错误 | 第 8.1 节的强制类型可以靠工程设置实现 |
| 测试脚本运行中出错后，进程 120 秒内没有退出，只能手动结束 | 运行器必须限时，超时判为失败 |
| 设置 `untyped_declaration=2`，测试方法内使用 `var x := 1` 并断言其值 | 导入和测试均退出 0，无警告或错误；推断类型可用 |
| RK-003 运行入口通过 `call()` 调用的测试方法数组越界后，同文件后续测试仍执行，Godot 正常退出 0 | 方法调用中的错误不会中止调用方；GDScript 断言汇总可能仍显示通过，Python 包装器根据 `SCRIPT ERROR` 及其之前最近的 `RUN` 行判整次失败（退出 1） |
| GDScript `int` 在 `9223372036854775807 + 1` 时得到 `-9223372036854775808`；`-1 >> 1` 得 `-1`；常量表达式里对负数右移会报解析错误 | 64 位加乘溢出会回绕；`>>` 是算术右移，逻辑右移要自己写（RK-005） |
| `RandomNumberGenerator` 设 `seed = 42` 后前 3 个 `randi()` 为 `492690617, 1919685028, 3561993920`；重设同一种子后序列从头重来 | 引擎随机算法的基准值，升级 Godot 后要重测（RK-005 用例 7） |
