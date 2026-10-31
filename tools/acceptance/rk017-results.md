# RK-017 验收记录

2026-10-31，Godot 4.7.2 / macOS Apple M1 / Compatibility OpenGL。从最新本地main `6cc7bb4`创建rk-017；fetch后main领先origin/main 28提交，远端无待同步更新。依赖RK012合并8cf9acf、RK014合并7b17b6e及RK004均在main。

新增WeaponState、输入/命令/事件字段、Sim武器步、InputCollector缓存及独立weapon_lab。project.godot仅在原[input]末尾追加fire（左键）、weapon_next（Q/滚轮上）、weapon_previous（滚轮下）三动作，原移动动作和其他设置未改。数据原值、旧资产/字体、boot、旧场景布局、空间哈希/固定步/边界与测试协议均未修改。

## 1. 初始状态、装备与事件

- `test_01_empty_independence_equipment_clear_and_atomic_errors`：新局两槽空、默认右向、独立实例；相同武器可装两槽。非法槽/武器/模式返回COMMAND_FAILED，完整状态（含冷却、身份、敌人、索引和四随机流）不变。清当前槽自动选另一非空槽；两槽空则停持续状态，无伪开火。装备/清空保留共享冷却。
- `test_01_all_eight_table_values_and_event_snapshot`：8个武器ID逐个核对独立表值期望，基础伤害/有效射速正确；玩家全局/近战伤害及满暴击不改变基础伤害。事件为整数玩家ID0、槽/武器/世界位置/方向及数值快照，之后换武器/改属性不会改变旧事件，不持有数据行或状态引用。

新武器框架不消耗敌人ID或随机流；默认空输入/空装备仍返回空事件。角色初始装备未写入Sim，观察场景自行通过命令装剑/杖。

## 2. 瞄准、处理顺序与槽切换

- `test_02_cardinal_diagonal_coincident_and_invalid_aim`：右/左/上/下、斜向单位方向正确，重合保持此前方向；无效/非有限瞄准不覆盖合法方向，不产生零向量或NaN。
- `test_02_move_then_aim_switch_then_fire_new_slot`：本步先移动玩家、更新敌人，再瞄准/换槽/处理开火；事件origin取本步玩家新位置。同一步换到杖并射击，先WEAPON_CHANGED后WEAPON_FIRED，均归槽1、学徒火杖，基伤12/攻速+100%有效4次每秒。净偶数切槽不产生换槽事件，空目标槽保持当前。

独立场景面板实际切到杖时显示完整ID、基础伤害12、表中/有效2次每秒；截图cache_staff_640.png保留证据。

## 3. 两种模式及解除锁定

- `test_03_hold_release_short_press_and_toggle_parity`：HOLD按住连发、松开停止，采样间完整短按仍能触发一次；TOGGLE一次按下开、再次按下关，松开仍持续，两次待消费按下从关闭净为关闭。空武器按下不会在以后装备时变成伪持续。
- `test_03_mode_change_stops_and_waits_for_fresh_press`：改模式立即停持续状态，保留冷却；旧held没有新边沿时持续100步仍不重新开火，松开再新按下才开启。持续状态跨合法换槽保留。

模式命令用最近采样的held建立release_required；新按下边沿也证明期间已完成松开，支持两个逻辑步之间的完整短按。观察场景改模式时清旧collector意图；失焦/退出经同模式SET_FIRE_MODE命令停火，不写PlayerState。

## 4. 射速与共享冷却

以下正式方法全部通过：

- `test_04_fractional_cadence_frames_and_counts`
- `test_04_shared_cooldown_switch_and_reequip_preserve_time`
- `test_04_release_repress_and_stat_changes_preserve_positive_timer`
- `test_04_idle_pause_ready_and_no_debt`
- `test_04_ready_single_then_wait`

| 600个连续开火逻辑步 | 实测发数 | 前6个开火步 |
|---|---:|---|
| 骑士剑，攻速0 | 16 | 1,39,76,114,151,189 |
| 学徒火杖，攻速0 | 20 | 1,31,61,91,121,151 |
| 骑士剑，攻速+100% | 32 | 1,20,39,58,76,95 |
| 学徒火杖，攻速+100% | 40 | 1,16,31,46,61,76 |
| 地精冲锋枪，攻速cap +300% | 320 | 1,3,5,7,9,11 |

每逻辑步至多一发；另6000步剑160发，验证长期不因逐次取整冷却变慢。冷却以Sim.DT扣正剩余，<=1e-9可发，成功后加本次1/有效射速，保留负余数。无开火需求仅清已到期负余数，正冷却继续倒计时；松开/重按不能清正冷却。首次或闲置就绪立即一发，不银行式积累闲置补射。

剑首发后下一步切到杖仍等原共享冷却；来回切槽/重装备不重置。已有冷却不随攻速属性变化重算，下次发射按新武器有效射速安排下一间隔。暂停不调用Sim.step，因此完全不消耗冷却。

## 5. 确定性、输入及事件快照

`test_05_replay_input_immutability_and_event_values`：240步同命令/输入逐字段重放相等，含移动、瞄准、TOGGLE、切槽和攻速变化。共享InputFrame在a.step后不改写，b.step得到相同事件/状态；事件数值快照稳定，随机流和敌人最终索引一致。原177项没有删除或放宽。

## 输入采集公开接口与图形实测

InputCollector保留sample()；新增configure(world_canvas: CanvasItem)、feed_event(event: InputEvent, allow_press: bool=true)、reset()。配置后sample内部调用世界CanvasItem.get_global_mouse_position；无配置旧场景仅移动、aim_valid=false、无开火边沿。生产Input读取集中于collector，场景只转发_input（allow_press=false收松开）及_unhandled_input（收合法按下/Q/滚轮）。

`rk017_graphical.gd`真实图形进程使用合成鼠标移动/按下/松开、Q含echo、滚轮事件，实际经过GUI处理及collector；不是实物鼠标/手柄试玩。为更新Godot实际鼠标位置，探针用Viewport.warp_mouse移动合成指针，再用push_input发送事件，结束恢复原屏幕指针位置；没有在生产collector里伪造坐标。

- 80ms不运行逻辑步时边沿仍保留；同渲染帧一次向原FixedStepDriver注入3.125×DT得到3个真实回调，采样依次(presses,switches)=(1,1),(0,0),(0,0)，Engine.get_frames_drawn前后不变。后续保留held，Q echo不计数，滚轮上下净步数正确。长检查分批delta遵守原驱动0.25秒上限，没有改驱动。
- 两次完整短按净关闭TOGGLE，HOLD短按可一发；两次Q回到原槽无假事件，滚轮下只算-1一次。
- 面板左键/滚轮不误开火或换槽；全局收GUI上的松开不粘滞。模式/攻速/重建/暂停/单步均有真实按钮命中检查。暂停时向原驱动传delta和等待渲染帧都不改变状态；单步恰一逻辑步。
- 失焦经Sim命令停止持续状态、清collector；恢复焦点不自动续射；reset后仍物理按住不伪造新按下，新按下才接受。退出场景也清输入并停火。
- 另开启场景原driver的自然_process：HOLD按住跨Q切槽，实际62步记录槽计数[1,1]、开火步[1,39]；TOGGLE完整短按并松开后持续，实际62步记录[2,0]、开火步[1,39]，第二次点击停止。没有用手动补步替代全部自然驱动检查。

## 世界坐标、窗口和截图

相机固定偏移(800,450)；完整数值记录见[graphical.json](rk017-evidence/graphical.json)，不仅比较方向：

| 逻辑视口/实际窗口 | 窗口事件坐标 | 视口鼠标 | canvas逆变换平移 | aim_world |
|---|---|---|---|---|
| 640×360 / 640×360 | (448,252) | (448,252) | (480,270) | (928,522) |
| 1280×720 / 1280×720 | (896,504) | (896,504) | (160,90) | (1056,594) |
| 640×360 / 1280×720，2× | (896,504) | (448,252) | (480,270) | (928,522) |

事件origin=(640,360)，方向=(0.871576,0.490261)，与(aim_world-origin).normalized一致。玩家视图位置精确等于逻辑位置且rotation=0，不把窗口/视口坐标冒充世界点。

实际Godot PNG路径`/private/tmp/rk017-checks/`，归档[rk017-evidence](rk017-evidence/)：default_hold_640、cache_staff_640，三种窗口组合的hold/toggle共6张。已人工查看：中文可读，完整ID、基础伤害、表中/有效射速、共享冷却、持续状态与两槽计数可读，按钮在视口内，控件几何无裁切/重叠。实际FontFile为项目Fusion Pixel、12px、禁系统回退，15段受测运行文本逐字符has_char通过。

瞄准线使用2px，避免项目像素吸附把1px斜线压没；不改项目吸附设置。每张hold/toggle PNG独立读回检查瞄准线#769EB5、准星#8FBDD3及事件标记#CEE5EC实际像素非零。均不超过#F0F0F0，不使用敌弹品红/深色圈。标记短暂显示方向，HUD明确标基础伤害/开火事件，不代表实际弹道、近战碰撞或最终伤害。偏移相机截图可见场地外清屏区域；默认相机另有完整玩家截图，未改竞技场边界。

## 30/60fps与故障自检

`rk017_verify.py`支持GODOT_BIN、任意cwd、Python3.9标准库及仓库标准库PNG读取器；先导入，每个Godot子进程timeout=45秒；非零、ERROR/SCRIPT ERROR、超时或成功标志缺失/重复均失败。唯一最终成功RK017: passed。

预生成600个逻辑输入，用正式FixedStepDriver分别实际限30/60fps运行；包含移动、按住、松开后重按、换槽及第300步攻速命令。两次均600逻辑步、25条开火事件，事件帧/武器/槽/基伤/有效射速/位置/方向全部一致。最近一次实际处理帧数302/599，用时9.969995/9.936898秒；以实际逻辑步与事件序列验收，不拿约10秒墙钟强制发数。原始JSON与日志归档。

| 临时故障（finally恢复原字节） | 指定失败依据 |
|---|---|
| 取消冷却 | ready_single_then_wait中下一步不应开火断言失败 |
| 切枪清零共享冷却 | shared_cooldown中正剩余期间切槽不得开火断言失败 |
| 每次开火丢负余数 | fractional_cadence帧序列及长期160发断言失败 |
| sample重复消费按下边沿 | 图形缓存样本变成重复press，edge cache consumed once失败；非纯模拟替代 |

每项要求退出1、唯一failed及指定行为断言同时出现，脚本错误/超时不算有效捕获。全部恢复后再次新验证通过。

## 最终回归和交付

- 完整run_tests.py：Python 46项、GDScript **189 passed, 0 failed**，17.148秒，低于60秒预算。
- RK012真实限帧与输入、RK014属性及其故障恢复、RK041敌人/密度/生命周期及其故障恢复独立验证全部通过；旧断言未改。
- art_check.py：100/100。
- [MCP记录](rk017-mcp.json)：启动weapon_lab、读取输出、停止完成，无ERROR/WARNING。
- git diff --check通过，新增6个game内脚本.uid一并交付。

命令输出及耗时均在rk017-evidence；归档日志仅清除行末空白，没有删除错误/断言内容。没有提交到main或合并分支。

和文档的出入：无。发现的其他问题：无。
