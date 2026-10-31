class_name WeaponLab
extends Node2D

var sim: Sim
var driver: FixedStepDriver
var collector: InputCollector = InputCollector.new()
var camera: Camera2D
var player_view: PlayerView
var debug_view: WeaponDebugView
var controls: Dictionary = {}
var steps: int = 0
var counts: Array[int] = [0,0]
var paused: bool = false
var last_input: InputFrame = InputFrame.new()
var last_events: Array[SimEvent] = []
# 只读调试轨迹，便于核对同渲染帧补步时的边沿消费。
var sampled_edges: Array[Vector2i] = []
var fired_frames: Array[int] = []

func _ready() -> void:
	if not OS.is_debug_build():
		return
	add_child(ArenaView.new())
	player_view = (load("res://view/battle/player_view.tscn") as PackedScene).instantiate() as PlayerView
	player_view.z_index = BattleDrawOrder.ENTITIES
	add_child(player_view)
	debug_view = WeaponDebugView.new()
	add_child(debug_view)
	camera = Camera2D.new()
	camera.position = ArenaBounds.play_rect().get_center()
	add_child(camera)
	_build_ui()
	collector.configure(self)
	driver = FixedStepDriver.new()
	driver.configure(_step)
	add_child(driver)
	reset_run()

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = BattleDrawOrder.HUD
	add_child(layer)
	var margin: MarginContainer = MarginContainer.new()
	margin.theme = preload("res://app/dev/debug_ui_theme.tres")
	layer.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	margin.offset_left = -632
	margin.offset_right = -8
	margin.offset_top = 8
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#12121C")
	for side: int in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		style.set_content_margin(side,4)
	panel.add_theme_stylebox_override("panel",style)
	panel.mouse_force_pass_scroll_events = false
	margin.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	panel.add_child(box)
	for key: String in ["Title","Identity","Timing","Counts"]:
		var label: Label = Label.new()
		label.name = key
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
		controls[key] = label
	controls.Title.text = "主武器框架 · 左键射击 · Q/滚轮换槽 · 仅方向事件标记"
	var row: HBoxContainer = HBoxContainer.new()
	box.add_child(row)
	for pair: Array in [["Hold","按住模式"],["Toggle","切换模式"],["Reset","重建"],["Pause","暂停"],["Step","单步"],["Speed","攻速 +0%"]]:
		var button: Button = Button.new()
		button.name = pair[0]
		button.text = pair[1]
		row.add_child(button)
		controls[pair[0]] = button
	controls.Hold.pressed.connect(set_mode.bind(WeaponState.FireMode.HOLD))
	controls.Toggle.pressed.connect(set_mode.bind(WeaponState.FireMode.TOGGLE))
	controls.Reset.pressed.connect(reset_run)
	controls.Pause.pressed.connect(func() -> void: set_paused(not paused))
	controls.Step.pressed.connect(single_step)
	controls.Speed.pressed.connect(_change_speed)

## 重建独立Sim，经装备命令配置观察用两槽，清掉旧输入与事件计数。
func reset_run() -> void:
	collector.reset()
	sim = Sim.new(20261031,&"knight")
	for pair: Array in [[0,&"knight_sword"],[1,&"apprentice_fire_staff"]]:
		var cmd: Command = Command.new()
		cmd.kind = Command.Kind.SET_WEAPON_SLOT
		cmd.slot_index = pair[0]
		cmd.weapon_id = pair[1]
		sim.apply(cmd)
	debug_view.reset()
	steps = 0
	counts = [0,0]
	sampled_edges.clear()
	fired_frames.clear()
	last_input = InputFrame.new()
	last_events = []
	driver.reset()
	set_paused(false)
	_sync()

## 修改模式通过Sim命令停火，并取消此前尚未消费的输入意图。
func set_mode(mode: int) -> void:
	collector.reset()
	var cmd: Command = Command.new()
	cmd.kind = Command.Kind.SET_FIRE_MODE
	cmd.fire_mode = mode
	sim.apply(cmd)
	_sync()

## 暂停不调用Sim.step，不改变冷却或持续模式状态。
func set_paused(value: bool) -> void:
	paused = value
	driver.set_paused(value)
	controls.Pause.text = "继续" if value else "暂停"
	if sim != null:
		_sync()

## 在暂停状态推进同一个正式采样/逻辑步回调。
func single_step() -> void:
	set_paused(true)
	_step()

func _change_speed() -> void:
	var cmd: Command = Command.new()
	cmd.kind = Command.Kind.SET_STAT_MODIFIER
	cmd.modifier_source = &"weapon_lab_speed"
	cmd.stat_mods = {&"attack_speed": 1.0 if sim.state.player.stats.value(&"attack_speed") == 0.0 else 0.0}
	sim.apply(cmd)
	_sync()

func _input(event: InputEvent) -> void:
	collector.feed_event(event,false)

func _unhandled_input(event: InputEvent) -> void:
	collector.feed_event(event)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and sim != null:
		_stop_input()

func _exit_tree() -> void:
	if sim != null:
		_stop_input()

func _stop_input() -> void:
	collector.reset()
	var cmd: Command = Command.new()
	cmd.kind = Command.Kind.SET_FIRE_MODE
	cmd.fire_mode = sim.state.player.weapon.fire_mode
	sim.apply(cmd)

func _step() -> void:
	last_input = collector.sample()
	last_events = sim.step(last_input)
	steps += 1
	sampled_edges.append(Vector2i(last_input.fire_presses,last_input.switch_steps))
	if sampled_edges.size()>120:
		sampled_edges.pop_front()
	for event: SimEvent in last_events:
		if event.kind == SimEvent.Kind.WEAPON_FIRED:
			counts[event.slot_index] += 1
			fired_frames.append(steps)
	_sync()
	debug_view.sync(sim.state.player,last_input,last_events)

func _sync() -> void:
	player_view.sync(sim.state.player)
	debug_view.sync(sim.state.player,last_input,[])
	var w: WeaponState = sim.state.player.weapon
	controls.Identity.text = "槽%d · %s · 基础伤害 %.2f（未计算最终伤害）" % [w.active_slot+1,w.slots[w.active_slot],w.base_damage]
	controls.Timing.text = "表中/有效射速 %.2f / %.2f 次/秒 · 共享冷却 %.4f 秒 · 持续 %s" % [w.base_shots_per_sec,w.effective_shots_per_sec,w.cooldown_remaining,"开" if w.firing else "关"]
	controls.Counts.text = "步数 %d · 槽1/2开火事件 %d / %d · %s · %s" % [steps,counts[0],counts[1],"按住" if w.fire_mode==WeaponState.FireMode.HOLD else "切换","已暂停" if paused else "运行中"]
	controls.Speed.text = "攻速 +%d%%" % roundi(sim.state.player.stats.value(&"attack_speed")*100)
