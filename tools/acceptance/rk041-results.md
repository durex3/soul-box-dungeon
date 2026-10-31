# RK-041 验收记录

2026-10-31；Godot 4.7.2 / macOS Apple M1 / Compatibility OpenGL。
从最新本地main `b4a4e9c` 创建 `rk-041`。已fetch确认远端无更新，本地主线领先origin/main 17个提交；依赖862d67a、b7fe413、0b1546b及RK012/011/120均已合入。

运行 `python3 tools/acceptance/rk041_verify.py`：支持GODOT_BIN、任意cwd、Python3.9标准库；先导入，每个Godot子进程timeout=45秒；非零、ERROR/SCRIPT ERROR、超时或标志缺失/重复均失败。唯一最终成功标志 `RK041: passed`。以下按任务要求顺序记录。

## 1. 数据构建、波次及危险系数

`test_eight_species_wave_danger_and_table_unchanged`：8个现有敌种，逐个核对原始生命/伤害/像素速度/经验、8px半径及出生波次/危险级别。独立参考表核对波次1/6/12：生命1/2.1/3.42、伤害1/1.6/2.32、经验1/1.3/1.66。危险0/1/5生命1/1.15/1.15、伤害1/1.10/1.10，经验不变；初始hp=max_hp。未调用工厂生成期望，没有取整。

`test_factory_instance_isolation`：纯工厂独立实例互不影响；生产Sim状态只经命令/step修改。EnemyTable序列化前后完全相同；dash_speed/child_xp原值保留。Balance仅追加GDD14的两项具名常量，不复制表中数值；EnemyConfig集中半径和8轮预算。

## 2. 正式命令、身份及查询

`test_command_ids_failure_atomicity_and_query_copy`：玩家ID0，出生返回SPAWNED整数ID1…；移除返回DESPAWNED并同步删除索引，重生不复用ID。未知敌种、wave<1、危险越界、未知命令、移除不存在ID、null命令返回COMMAND_FAILED，快照/计数器/索引不变，无push_error。首次出现波次不限制直接出生。查询不含玩家，返回副本。

`test_index_cross_bucket_and_removal_after_motion`：追击/分离后的查询与独立逐点参考精确相同，跨桶迁移与移除不留旧记录。Sim私有持有正式SpatialHash，query_enemies仅委托中心点查询。

## 3. 基础追击

`test_isolated_axial_and_diagonal_speed`：孤立骷髅鼠72px/s、僵尸40px/s，直线/斜线60步位移在±0.02px内。`test_player_first_retarget_arrive_and_exact_coincidence`：先更新玩家，再追击本步目标；近目标不越过、同点不振荡，玩家向下再向右后重新追击。出生位置全部由命令安排。

## 4. 两圆、同点与墙角

`test_pairs_apart_tangent_overlap_and_coincident`、`test_three_coincident_resolve_non_collinear_deterministically`、`test_four_walls_four_corners_stay_bounded_and_leave_wall`：相离/相切/重叠/同点、三圆同点、四边四角均通过；坐标有限，整圆受约束，随后能离墙。`test_coincident_direction_uses_full_id_history`额外核对移除历史后ID1/9/17完全同点，仍能在二维解开。

实现为有界软位置修正，最多8轮/逻辑步，追击严格move_speed×DT。没有完全同点时8轮有序逐对半重叠修正；有同点时第1轮用同一快照累计同点对修正，之后7轮有序逐对修正，不额外增加预算。每对低ID先于高ID，每轮只处理一次；两个位置每次提交均立即更新正式索引。邻域半径为当前半径+本帧最大敌人半径；生产运动不做全体O(N²)候选筛选。

同点方向：有序ID对先乘73856093/19349663并xor，经两次32位混合（0x45d9f3b）及右移xor；结果两个16位字段映射为[-65535,65535]的奇数分量后单位化，保证非零。不只取ID低3位，不调用随机。不使用预设站位或阵列传送；同点快照修正避免首对解开后其余对退化同轴。采用任务允许的确定性单位方向实现，并非限制为建议的8个方向。

## 5. 固定200夹具与移动跟随

`test_standard_200_density_600_steps`：严格20列×10行、(64+24列,64+24行)、200骷髅鼠、玩家初始中心静止、600步。每步检查完整边界、有限坐标、严格升序身份恰为1…200。最终用独立全体遍历计算最近邻，不借用生产索引作为参考：

| 指标 | 实测 | 要求 |
|---|---:|---:|
| 最小距离 | 14.775475px | ≥8px |
| 第5百分位（nearest rank，第10小） | 14.801676px | 留档 |
| 中位数（第100/101小平均） | 15.326491px | 留档 |
| 最近邻≥14px | 200/200 | ≥190/200 |
| 小于14px | 0 | ≤10 |

`test_200_follow_right_then_down`：再以玩家向右300步、向下300步输入检查群体均值随方向前进，全程整圆在界内、身份仍恰为1…200，最终索引与独立参考一致。

恢复故障后的独立计时（仅Sim.step，不含统计/渲染）：8轮预算，600步平均11.478ms、最大27.365ms；总逻辑探针约6.97秒。无硬性能门槛，不把单个M1逻辑步记录当作RK010整场60fps结论。

## 6. 确定性与随机流

`test_replay_queries_lifecycle_and_rng_unchanged`：两个种子，同命令、输入、删除/重生历史；每步逐个ID/位置/全部属性精确相等。一侧额外查询不改变当前或后续结果。spawn/shop/loot/upgrade四条流状态全程等于出生前；hp/damage/xp不被运动修正改变。

## 7. 完整回归

`python3 tools/run_tests.py`通过：Python 46项、GDScript 166 passed / 0 failed；总用时见[full-time.txt](rk041-evidence/full-time.txt)，低于architecture的60秒预算。原玩家移动、空间哈希和固定步断言未改。

额外`rk012_verify.py`正式驱动30/60fps、0/+50%、键盘/摇杆输入通过；`tools/art_check.py`100/100。未修改旧验收脚本、测试协议、SpatialHash、固定步或ArenaBounds算法。

## 独立观察场景及图形探针

`res://app/dev/enemy_chase_lab.tscn`仅debug独立运行；复用ArenaView、PlayerView、InputCollector及场景原有FixedStepDriver。创建200/重置/继续暂停/单步全部通过合成鼠标事件命中；键盘合成D输入经采集和单步推进。未用实物鼠标/手柄试玩。

实际图形进程使用场景原驱动运行到至少600步，再发暂停事件；本次暂停在629步（按钮事件前仍按固定步推进），并非把629步画面冒称标准600步数值验收。图形最终最近邻最小14.892917px、P5=14.949821px、中位15.293581px、低于14px为0；独立参考统计与显示一致。数量/步数、每只View的位置、scale=1及实体层、玩家显示位置均与模拟精确一致。单步操作暂停且只推进一步，暂停时不积累逻辑时间；重置后状态/索引清空，重新创建的新局身份从1开始。

本地RK120 Theme明确覆盖控件，12px、项目Fusion Pixel、禁系统回退；运行文字11段去重、61个码位全部has_char通过，清单见[glyphs.json](rk041-evidence/glyphs.json)。逐控件检查视口范围、文字高度/按钮文字宽度与相互重叠。

实际Godot截图位于`/private/tmp/rk041-checks/`并归档：
- [1280全图群体](rk041-evidence/crowd_after600_1280.png)、[640局部](rk041-evidence/crowd_after600_640.png)
- cold_1280、spawn_1280、reset_640、respawn_640

已人工查看：200圆形标记保持8px逻辑半径和原尺寸绘制，不缩小素材或改写状态；群体未重叠为一个点，中文无方框/截断。右上暗底面板避免初始标记干扰文字；这只是基础圆形标记，不替代RK042敌种轮廓/动画。

[Godot MCP记录](rk041-mcp.json)：启动、读取输出、停止完成，无ERROR或WARNING。MCP冷启动不替代上述200群体验证。

## 故意改坏及恢复

`rk041_verify.py`内每项以finally恢复原字节，预期失败必须同时有非零退出码、唯一failed标志及指定断言；脚本错误或超时不算成功捕获：

1. 生命公式wave-1改wave：独立波次属性near断言失败。
2. 迭代预算8改0：200夹具最小/P5/中位均0，200只均小于14px，两项固定密度阈值失败；基线明显失败，夹具有效。
3. 漏同步被推开另一实体的空间索引：跨桶最终查询与逐点参考失败。
4. 取消同点方向（返回Vector2.ZERO）：三圆同点解开/非共线断言失败。

恢复后独立正向逻辑、图形、完整测试全部通过。日志归档仅去除行末空白，未删改检查输出。git diff --check通过，新增game内GDScript的.uid齐全。

和文档的出入：无。范围外问题：无。未改docs、project.godot、boot、旧美术源/PNG/JSON，没有实现攻击、精英、自动波次、死亡奖励或Godot物理。
