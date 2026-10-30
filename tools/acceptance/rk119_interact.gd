extends SceneTree
## 图形模式交互复查：实际鼠标事件命中控件，再读取结果与渲染像素。

var _lab: AssetReviewLab
var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(640, 360)
	root.content_scale_size = Vector2i(640, 360)
	_lab = (load("res://app/dev/asset_review_lab.tscn") as PackedScene).instantiate() as AssetReviewLab
	root.add_child(_lab)
	await process_frame
	await process_frame
	for entry: Dictionary in _lab.catalog.entries:
		if str(entry["path"]).ends_with("/chr_knight_run.json"):
			_choose("Object", entry["category"] + "/" + entry["id"])
			_choose("Action", entry["action"])
	if _lab.resource.get("frames", []).is_empty() and not "--bad" in OS.get_cmdline_user_args():
		_check(false, "no playable resource: " + str(_lab.resource))
		await _finish()
		return
	if "--bad" in OS.get_cmdline_user_args():
		_check(not _lab.resource["error"].is_empty() and not _lab.playing, "bad resource stopped")
		_check(str(_lab.resource["error"]).contains("chr_knight_run.json"), "specific file shown")
		print("RK119 bad UI: " + str(_lab.resource["error"]))
		_choose("Object", "player/alchemist")
		_check(_lab.resource["error"].is_empty(), "other resource remains selectable")
		_finish()
		return
	_check(_lab.resource["frames"][0]["duration"] == 83.0, "knight run duration=83ms")
	await _click("First")
	await create_timer(1.0).timeout
	_check(_lab.frame_index == 0 and not _lab.playing, "pause holds for 1s")
	await _click("Next")
	await create_timer(0.2).timeout
	_check(_lab.frame_index == 1 and not _lab.playing, "next advances exactly one and pauses")
	await _click("Previous")
	_check(_lab.frame_index == 0 and not _lab.playing, "previous advances exactly one and pauses")
	await _click("First")
	await _click("Previous")
	_check(_lab.frame_index == _lab.resource["frames"].size() - 1, "loop step wraps first to last")
	await _click("Play")
	await create_timer(0.1).timeout
	await _click("Play")
	_check(_lab.frame_index == 0, "playing last wraps to first")
	await _click("First")
	await _click("Previous")
	await _click("Loop")
	await _click("Play")
	await create_timer(0.2).timeout
	_check(not _lab.playing and _lab.frame_index == _lab.resource["frames"].size() - 1, "nonloop stops at last")
	await _click("First")
	_check(_lab.frame_index == 0, "first resets zero")
	await _key(KEY_RIGHT)
	_check(_lab.frame_index == 1 and not _lab.playing, "keyboard right steps while button focused")
	await _key(KEY_HOME)
	_check(_lab.frame_index == 0 and not _lab.playing, "keyboard Home resets")
	await _key(KEY_SPACE)
	_check(_lab.playing, "keyboard Space starts")
	await _key(KEY_SPACE)
	_check(not _lab.playing and Engine.time_scale == 1.0, "keyboard Space pauses; global clock untouched")
	await _click("First")
	for speed_text: String in ["0.25×", "0.5×", "1×", "2×"]:
		_choose("Speed", speed_text)
		print("RK119 speed: ", _lab.speed)
	_choose("Speed", "1×")
	# 实际点击截图按钮，读取工具写出的同帧画面而非重新绘制素材。
	await _click("Pivot")
	await _click("Baseline")
	_choose("Background", "灰底")
	await _click("Export")
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var frame: Dictionary = _lab.resource["frames"][_lab.frame_index]
	var size: Vector2i = Vector2i(frame["rect"].size)
	var offset: Vector2 = _lab.preview.global_position
	var one: Vector2i = Vector2i(offset + _lab.preview.pivot_at(0) - frame["pivot"])
	var three: Vector2i = Vector2i(offset + _lab.preview.pivot_at(1) - frame["pivot"] * 3)
	var mismatches: int = 0
	for y: int in size.y:
		for x: int in size.x:
			for dy: int in 3:
				for dx: int in 3:
					if image.get_pixelv(one + Vector2i(x, y)) != image.get_pixelv(three + Vector2i(x * 3 + dx, y * 3 + dy)):
						mismatches += 1
	_check(mismatches == 0, "1x/3x exact 3x3 pixel blocks (%d mismatches)" % mismatches)
	for material: String in ["原色", "灰度", "纯黑剪影（排除投影）"]:
		_choose("Material", material)
		for background: String in ["区域1地面 #1C1B26", "灰底", "透明棋盘"]:
			_choose("Background", background)
			await process_frame
			await RenderingServer.frame_post_draw
			print("RK119 visible: ", material, " / ", background)
		_choose("Background", "灰底")
		await _click("Export")
	_choose("Material", "原色")
	_choose("Background", "区域1地面 #1C1B26")
	_choose("Object", "enemy/charge_boar")
	_check(_lab.current["action"] == "run" and _lab.frame_index == 0, "compatible action retained; reset frame")
	_choose("Object", "soul/fireball")
	_choose("Tier", "T4")
	_check(_lab.frame_index == 0 and not _lab.playing and _lab.resource["frames"].size() == 1, "T4 static clears animation")
	_check(_lab.resource["frames"][0]["pivot"] == Vector2(6, 6), "T4 body-center pivot")
	for tier: int in range(1, 5):
		_choose("Tier", "T%d" % tier)
		print("RK119 tier: ", tier, " frame=", _lab.resource["frames"][0])
	_choose("Tier", "T4")
	await _click("HideNames")
	_check(not _lab.preview.caption.contains("fireball") and not (_lab.widgets.controls["Details"] as Label).text.contains("fireball"), "blind preview and answer hidden")
	# 侧栏在小窗口可滚动；定位答案复选框后再发鼠标事件。
	await _click("Answer")
	_check(not _lab.preview.caption.contains("fireball") and (_lab.widgets.controls["Details"] as Label).text.contains("fireball"), "answer revealed only in sidebar")
	await _click("HideNames")
	_choose("Category", "标签")
	var objects: OptionButton = _lab.widgets.controls["Object"]
	_check(objects.item_count == 7, "all seven tag icons selectable")
	for i: int in objects.item_count:
		objects.select(i)
		objects.item_selected.emit(i)
		await process_frame
		await RenderingServer.frame_post_draw
		_check(_lab.resource["frames"][0]["rect"].size == Vector2(8, 8), "tag 1x 8x8: " + _lab.current["id"])
	await _click("Export")
	# 对照两种真实窗口尺寸，检查主要控件在可见视口内。
	for dimensions: Vector2i in [Vector2i(640, 360), Vector2i(1280, 720)]:
		root.size = dimensions
		await process_frame
		await process_frame
		for key: String in ["Play", "Previous", "Next", "First", "Loop", "Speed", "Export", "State"]:
			var control: Control = _lab.widgets.controls[key]
			_check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(control.get_global_rect()), "layout %s %s" % [dimensions, key])
	root.size = Vector2i(640, 360)
	_choose("Category", "全部类别")
	_choose("Object", "player/knight")
	_choose("Action", "run")
	await _click("First")
	var sidebar: ScrollContainer = (_lab.widgets.controls["Category"] as Control).get_parent().get_parent() as ScrollContainer
	sidebar.scroll_vertical = 0
	await process_frame
	await _click("Export")
	_finish()

func _choose(key: String, text: String) -> void:
	var option: OptionButton = _lab.widgets.controls[key]
	for i: int in option.item_count:
		if option.get_item_text(i) == text:
			option.select(i)
			option.item_selected.emit(i)
			return
	_check(false, "missing choice: " + key + "=" + text)

func _click(key: String) -> void:
	var control: Control = _lab.widgets.controls[key]
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await process_frame
	var position: Vector2 = control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame

func _check(condition: bool, message: String) -> void:
	print("RK119 UI ", "OK " if condition else "FAIL ", message)
	_failed = _failed or not condition

func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame

func _finish() -> void:
	print("RK119_INTERACT: " + ("failed" if _failed else "passed"))
	_lab.queue_free()
	await process_frame
	quit(1 if _failed else 0)
