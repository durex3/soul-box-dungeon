extends SceneTree
## 实际图形场景 + 合成鼠标/键盘，检查正式驱动及只读显示。

var lab: EnemyChaseLab
var failed: bool = false
var texts: Dictionary = {}
var cps: Dictionary = {}
var out: String

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, reason: String) -> void:
	if not ok:
		print("RK041 GRAPH FAIL ", reason)
		failed = true

func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _click(key: String) -> void:
	await _settle()
	var pos: Vector2 = lab.controls[key].get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = pos
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _settle()

func _audit() -> void:
	for control: Control in lab.controls.values():
		var font: Font = control.get_theme_font("font")
		_check(font.resource_path == "res://assets/fonts/fusion-pixel-12px-zh_hans.woff2" and font is FontFile and not font.allow_system_fallback, "explicit project font " + control.name)
		_check(control.get_theme_font_size("font_size") == 12, "font size " + control.name)
		texts[control.text] = true
		for c: String in control.text:
			if c.unicode_at(0) >= 32:
				cps["U+%04X" % c.unicode_at(0)] = c
				_check(font.has_char(c.unicode_at(0)), "missing glyph " + c)
		_check(root.get_visible_rect().encloses(control.get_global_rect()), "viewport " + control.name)
		if control is Label:
			_check(control.get_line_count() * control.get_line_height() <= control.size.y + 0.01, "label geometry " + control.name)
		else:
			_check(font.get_string_size(control.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + control.get_theme_stylebox("normal").get_minimum_size().x <= control.size.x, "button geometry " + control.name)
		for other: Control in lab.controls.values():
			if other != control:
				_check(not control.get_global_rect().intersects(other.get_global_rect()), "text overlap " + control.name + "/" + other.name)
	_check(lab.views.size() == lab.sim.state.enemies.size(), "view count equals sim")
	for enemy: EnemyState in lab.sim.state.enemies:
		var view: EnemyDebugView = lab.views[enemy.entity_id]
		_check(view.position == enemy.position and view.scale == Vector2.ONE and view.z_index == BattleDrawOrder.ENTITIES, "exact view position/scale/layer")
	_check(lab.player_view.position == lab.sim.state.player.position, "player exact sync")
	_check(lab.controls.Status.text.contains("敌人数 %d" % lab.sim.state.enemies.size()) and lab.controls.Status.text.contains("步数 %d" % lab.steps), "display actual counters")

func _capture(name: String) -> void:
	await _settle()
	_audit()
	_check(root.get_texture().get_image().save_png(out.path_join(name + ".png")) == OK, "actual viewport PNG")

func _run() -> void:
	out = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.grab_focus()
	await create_timer(0.2).timeout
	lab = (load("res://app/dev/enemy_chase_lab.tscn") as PackedScene).instantiate() as EnemyChaseLab
	root.add_child(lab)
	await _capture("cold_1280")
	await _click("Create")
	_check(lab.sim.state.enemies.size() == 200 and lab.steps == 0 and lab.paused, "create mouse hit paused exact fixture")
	await _capture("spawn_1280")
	await _click("Step")
	_check(lab.steps == 1 and lab.paused, "single step mouse hit exactly one")
	await create_timer(0.1).timeout
	_check(lab.steps == 1, "paused holds")
	# 使用场景原有的正式固定步驱动，达到600步后发送暂停鼠标事件。
	await _click("Pause")
	_check(not lab.paused, "continue mouse hit")
	while lab.steps < 600:
		await process_frame
	await _click("Pause")
	_check(lab.paused and lab.steps >= 600, "pause mouse hit after 600 fixed steps")
	var stats: Dictionary = EnemyTestFixture.density(lab.sim)
	print("RK041 graphic final steps=", lab.steps, " ", stats)
	_check(stats.min >= 8.0 and stats.below14 <= 10 and EnemyTestFixture.index_matches(lab.sim), "graphic 200 density/index")
	_check(lab.density == stats, "display stats independent reference")
	await _capture("crowd_after600_1280")
	root.size = Vector2i(640, 360)
	root.content_scale_size = root.size
	await _capture("crowd_after600_640")
	# 键盘事件经正式InputCollector采集，显示玩家与敌人位置不写state。
	var before: Vector2 = lab.sim.state.player.position
	var before_steps: int = lab.steps
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_D
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _click("Step")
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	_check(lab.steps == before_steps + 1 and lab.sim.state.player.position.x > before.x, "single step uses collected input")
	await _click("Reset")
	_check(lab.steps == 0 and lab.paused and lab.sim.state.enemies.is_empty() and lab.sim.query_enemies(Vector2.ZERO, 2000).is_empty(), "reset clears states/index via new Sim")
	await _capture("reset_640")
	await _click("Create")
	_check(lab.sim.state.enemies.size() == 200 and lab.sim.state.enemies[0].entity_id == 1, "new run fresh identity counter")
	await _capture("respawn_640")
	var file: FileAccess = FileAccess.open(out.path_join("glyphs.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"texts": texts.keys(), "codepoints": cps, "synthetic_input": true}, "\t") + "\n")
	file.close()
	lab.queue_free()
	await process_frame
	print("RK041_GRAPHICAL: " + ("failed" if failed else "passed"))
	quit(1 if failed else 0)
