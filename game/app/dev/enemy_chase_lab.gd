class_name EnemyChaseLab
extends Node2D
## 独立debug观察场景；所有状态改变仅经Sim命令/step/重新建局。

var sim: Sim
var steps: int = 0
var driver: FixedStepDriver
var player_view: PlayerView
var views: Dictionary = {}
var controls: Dictionary = {}
var paused: bool = true
var density: Dictionary = {}
var _collector: InputCollector = InputCollector.new()

func _ready() -> void:
	if not OS.is_debug_build():
		return
	var arena: ArenaView = ArenaView.new()
	arena.z_index = BattleDrawOrder.BACKGROUND
	add_child(arena)
	player_view = (load("res://view/battle/player_view.tscn") as PackedScene).instantiate() as PlayerView
	player_view.z_index = BattleDrawOrder.ENTITIES
	player_view.z_as_relative = false
	add_child(player_view)
	var camera: Camera2D = Camera2D.new()
	camera.position = ArenaBounds.play_rect().get_center()
	add_child(camera)
	_build_ui()
	driver = FixedStepDriver.new()
	driver.configure(_step)
	add_child(driver)
	reset_run()

func _build_ui() -> void:
	var overlay: CanvasLayer = CanvasLayer.new()
	overlay.layer = BattleDrawOrder.HUD
	add_child(overlay)
	var margin: MarginContainer = MarginContainer.new()
	margin.theme = preload("res://app/dev/debug_ui_theme.tres")
	overlay.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	margin.offset_left = -632
	margin.offset_top = 8
	margin.offset_right = -8
	var panel: PanelContainer = PanelContainer.new()
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color("#12121C")
	for side: int in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		panel_style.set_content_margin(side, 4.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	margin.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	panel.add_child(box)
	for key: String in ["Title", "Status", "Density"]:
		var label: Label = Label.new()
		label.name = key
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
		controls[key] = label
	controls.Title.text = "敌人基础观察 · 8px圆形标记 · WASD / 左摇杆"
	var row: HBoxContainer = HBoxContainer.new()
	box.add_child(row)
	for pair: Array in [["Create", "创建200只"], ["Reset", "重置"], ["Pause", "继续"], ["Step", "单步"]]:
		var button: Button = Button.new()
		button.name = pair[0]
		button.text = pair[1]
		row.add_child(button)
		controls[pair[0]] = button
	controls.Create.pressed.connect(create_standard)
	controls.Reset.pressed.connect(reset_run)
	controls.Pause.pressed.connect(func() -> void: set_paused(not paused))
	controls.Step.pressed.connect(single_step)

## 清空观察对象并重建模拟，不能从界面直接清空RunState数组。
func reset_run() -> void:
	for view: EnemyDebugView in views.values():
		view.queue_free()
	views.clear()
	sim = Sim.new(20261031, &"knight")
	steps = 0
	driver.reset()
	set_paused(true)
	_update_density()
	_sync()

## 通过正式出生意图创建固定20列10行标准夹具，创建后暂停便于核对。
func create_standard() -> void:
	reset_run()
	for y: int in 10:
		for x: int in 20:
			var cmd: Command = Command.new()
			cmd.kind = Command.Kind.SPAWN_ENEMY
			cmd.enemy_type = &"skeleton_rat"
			cmd.position = Vector2(64 + 24 * x, 64 + 24 * y)
			sim.apply(cmd)
	_update_density()
	_sync()

## 暂停不累计逻辑余数；继续仍使用正式固定步驱动。
func set_paused(value: bool) -> void:
	paused = value
	driver.set_paused(value)
	controls.Pause.text = "继续" if value else "暂停"
	if sim != null:
		if value:
			_update_density()
		_sync()

## 单步与驱动共享同一回调，操作后保持暂停。
func single_step() -> void:
	set_paused(true)
	_step()
	_update_density()
	_sync()

func _step() -> void:
	sim.step(_collector.sample())
	steps += 1
	if steps % 60 == 0:
		_update_density()
	_sync()

func _sync() -> void:
	player_view.sync(sim.state.player)
	var alive: Dictionary = {}
	for enemy: EnemyState in sim.state.enemies:
		alive[enemy.entity_id] = true
		if not views.has(enemy.entity_id):
			var view: EnemyDebugView = (load("res://view/battle/enemy_debug_view.tscn") as PackedScene).instantiate() as EnemyDebugView
			views[enemy.entity_id] = view
			add_child(view)
		views[enemy.entity_id].sync(enemy, sim.state.player.position)
	for id: int in views.keys():
		if not alive.has(id):
			views[id].queue_free()
			views.erase(id)
	controls.Status.text = "敌人数 %d · 步数 %d · %s · 玩家 %s" % [sim.state.enemies.size(), steps, "已暂停" if paused else "追击中", sim.state.player.position]
	controls.Density.text = "最近邻 最小 %.2f / P5 %.2f / 中位 %.2f px · 小于14px %d只 · 每60步更新" % [density.min, density.p5, density.median, density.below14]

func _update_density() -> void:
	# 独立观察统计允许全体遍历，每60步才更新；运动候选只在Sim中走空间哈希。
	var distances: Array[float] = []
	var below: int = 0
	for a: EnemyState in sim.state.enemies:
		var nearest: float = INF
		for b: EnemyState in sim.state.enemies:
			if a.entity_id != b.entity_id:
				nearest = minf(nearest, a.position.distance_to(b.position))
		distances.append(nearest)
		if nearest < 14.0:
			below += 1
	distances.sort()
	density = {"min": 0.0, "p5": 0.0, "median": 0.0, "below14": below}
	if distances.size() > 1:
		density.min = distances[0]
		density.p5 = distances[maxi(0, ceili(distances.size() * 0.05) - 1)]
		density.median = (distances[floori((distances.size() - 1) * 0.5)] + distances[floori(distances.size() * 0.5)]) * 0.5
