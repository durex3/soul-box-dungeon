# RK-014 验收记录

2026-10-31，Godot 4.7.2 / macOS Apple M1。从最新本地main `127a27a`创建rk-014；fetch后确认main领先origin/main 23提交，远端无待同步提交。依赖862d67a、RK012合并8cf9acf、RK041合并362d5ab均在main。

实现只改模拟层：新增StatBlock、PlayerState独立属性容器，Command/SimEvent追加属性命令/事件，Sim构造与移动接入；没有修改数据原值、敌人运动、空间哈希/固定步/边界、UI/字体、美术、project.godot、boot或docs。

## 1. 18字段默认值、单位与隔离

`test_01_defaults_exact_keys_units_and_isolation`通过。独立GDD/RK004参考核对确切18键、默认浮点值及字段顺序：max_hp/hp_regen/lifesteal/armor/dodge/damage/melee_damage/ranged_damage/elemental_damage/attack_speed/crit_chance/area/move_speed/range/pickup_range/luck/income/max_energy。百分比按小数，暴击0.05+0.02=0.07；拾取范围2+0.5=2.5格，收益0.125不取整。两个容器互不影响。

生产默认值/cap/floor全部读取Balance，不硬编码第二套表。snapshot缓存为18字段有效值副本，字段顺序按STAT_BASE；输出探针JSON关闭自动键排序，保留该顺序。max_hp_pct不作为第19字段。

## 2. 上下限

`test_02_all_caps_floors_and_uncapped_values`通过。逐个独立期望核对7个cap：吸血0.25、闪避0.6、攻速3、暴击1、范围2、移速1、射程1。每个字段减到负值时，生命10、护甲-20、其余0；没有cap的字段保留大正数及小数，移除来源恢复默认值。

## 3. 玻璃大炮、生命顺序与恢复

`test_03_glass_from_relic_table_fixed_health_and_removal`从RelicTable实际读取玻璃大炮mods，通过：两实例来源生命56.25、全局伤害0.6；加固定生命20后67.5；依次移除两玻璃为90、120，再移除固定值回100。数据表序列化前后不变。

`test_03_health_floor_and_nonnegative_factors_recover_raw_sources`通过：10份玻璃最低10；移除至只剩2份恢复56.25，未从已夹到10的值倒除。固定生命减到负、-100%及低于-100%的两个因子均安全；每个因子max(0,1+值)，不出现两个负因子相乘反而回血；移除后回100。

## 4. 原始来源先汇总后截断

`test_04_raw_sum_then_clamp_and_source_restoration`通过：0.8+0.8-0.9=0.7，移除负来源=1，再移除一个正来源=0.8；-0.3暂显示0，再加0.5=0.2。来源更改时从Balance基础与全部原始修正重算；不在旧有效值上增量运算。

## 5. 来源、校验、拷贝与固定顺序

`test_05_replace_remove_deep_copy_and_deterministic_order`通过：同source整体替换不叠加，替换后旧字段不残留；空mods是可移除来源，不存在remove返回false。外部改原字典并触发下一次重算，不影响内部；snapshot改值/加键不影响容器。不同来源插入顺序、mods键插入顺序输出逐字段完全相同；用1e16/-1e16/0.125的非结合浮点例子确认按来源字符串排序，而非仅使用恰好可交换的简单样本。

`test_05_invalid_input_is_atomic_and_extras_rejected`通过：空source、非StringName键、未知键、bool/字符串/NaN/INF/-INF值、正max_hp_pct和其余RELIC_EXTRA_MODS全部拒绝。混合有效/无效项整体失败，既有来源和值保留，后续重算也不泄漏失败来源。合法int/float和非正max_hp_pct接受，正常失败不push_error。

## 6. Sim命令、兼容与移动

- `test_06_events_failures_and_enemy_identity_index_rng_unchanged`：每次成功仅一条STATS_CHANGED、entity_id=0、空reason；cap遮住的set仍保留原值100，后续加-99.2得到0.8。失败COMMAND_FAILED、无部分写入，镜像不变；敌人属性/位置/索引、随机流、后续敌人ID均不受影响。事件不携带容器/字典引用。
- `test_06_initial_compatibility_reserved_source_and_independent_runs`：旧签名保留，构造初始-2/0/0.5/2先夹到0—1，再存入initial_move_speed保留来源。以之后添加正/负来源确认保留的是预先夹取值，而非原始±2。外部命令set/remove此来源均失败，两局属性独立。
- `test_06_movement_initial_command_replace_remove_half_and_diagonal`：所有集成修改经命令，不直接写Sim状态。初始0/+50%的60步位移64/96px；命令+50%为96px，超cap为128px；替换+25%为80px，移除回64px；半幅与斜向在0.02px误差内。移动读取stats.value(move_speed)，move_speed_bonus仅作同步兼容镜像。
- `test_06_replay_mixed_source_histories_and_input`：120步中添加、替换、移除混合来源及变向输入，逐步状态/快照相同，镜像一致，随机流不变，敌人最终查询仍正确。

独立输出实际记录：初始64px样本63.999023px；初始与命令96px样本95.998535px；cap128px样本128.001709px，均在原0.02px误差内。其余17字段仅完成计算存储，不实现当前生命/伤害/暴击等行为。

## 7. 独立探针、故障与全部回归

`python3 tools/acceptance/rk014_verify.py`通过（也从/private/tmp以绝对脚本路径运行通过）。Python3.9标准库、支持GODOT_BIN；先导入，每个Godot子进程timeout=45秒；非零/错误/超时/标志缺失或重复均失败，唯一最终成功标志RK014: passed。

探针直接运行生产StatBlock/Sim及上述11个正式测试方法，打印18字段快照、玻璃/固定/移除后的生命、命令事件及60步距离。非法value仅在指定子进程精确接受下面两条ERROR，顺序/数量/文本及唯一RK014_QUERY: passed均须符合；返回值0、快照仍18字段，其他错误或SCRIPT ERROR仍失败：

- StatBlock.value 未知属性: max_hp_pct
- StatBlock.value 未知属性: unknown

四项临时故障均在finally恢复精确原字节，要求退出1、唯一failed及指定断言同时出现，脚本错误/超时不算捕获：

| 故障 | 实测捕获 |
|---|---|
| 生命减益求和再乘 | 两玻璃得到50，56.25断言失败 |
| 去掉生命最低10 | 十份玻璃最低值断言失败 |
| 对已截断缓存加raw total的增量 | 0.8+0.8-0.9错成0.1；移除正来源错成0.2；-0.3+0.5错成0.5，三项断言失败 |
| 移动读旧镜像且命令不更新镜像 | 命令+50%位移仍64，96px断言失败 |

恢复后新探针和完整测试通过，旧回归没有放宽断言：

- 完整run_tests.py：Python 46项通过；GDScript **177 passed, 0 failed**，总用时约17.85秒，低于60秒预算。
- rk012_verify.py：真实30/60fps驱动、0/+50%、键盘/摇杆合成输入通过。
- rk041_verify.py：敌人生命周期、600步200只密度、同点/索引与故障恢复、正式驱动观察通过。完整测试同时保留原166项，包括逐字段重放、墙角和移动群体断言。
- art_check.py：100/100。
- [MCP记录](rk014-mcp.json)：启动原player_movement_lab，读输出后停止，无错误/警告。未增加面板或按钮，不以MCP启动替代属性数值测试。
- git diff --check通过；新增StatBlock及两个正式测试的.uid一并交付。

详细命令输出、错误精准匹配、四项故障及耗时归档在[rk014-evidence](rk014-evidence/)。日志仅清理行末空白，未删除断言/错误内容。临时夹具/故障改动全部恢复，没有提交到main。

和文档的出入：无。发现的其他问题：无。
