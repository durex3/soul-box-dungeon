extends SceneTree
## 图形进程中真实输入、滚动范围和导出验证；不替代原尺寸人工辨认。

var _lab: AssetReviewLab
var _failed: bool = false
var _out: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_out = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(640, 360)
	root.content_scale_size = Vector2i(640, 360)
	_lab = (load("res://app/dev/asset_review_lab.tscn") as PackedScene).instantiate() as AssetReviewLab
	root.add_child(_lab)
	await process_frame
	await process_frame
	_choose("Category", "Boss")
	_check((_lab.widgets.controls["Object"] as OptionButton).item_count == 2, "two Boss objects")
	if "--bad" in OS.get_cmdline_user_args():
		_choose("Object", "boss/gravekeeper")
		_choose("Action", "idle")
		_check(not _lab.playing and not _lab.resource["error"].is_empty(), "bad Boss resource stops")
		_check(str(_lab.resource["error"]).contains("bos_gravekeeper_idle.json"), "specific bad Boss filename")
		print("RK075 bad Boss: ", _lab.resource["error"])
		_choose("Object", "boss/furnace_colossus")
		_check(_lab.resource["error"].is_empty(), "other Boss remains selectable")
		print("RK075_BAD: " + ("failed" if _failed else "passed"))
		_lab.queue_free()
		await process_frame
		quit(1 if _failed else 0)
		return
	for dimensions: Vector2i in [Vector2i(640, 360), Vector2i(1280, 720)]:
		root.size = dimensions
		await process_frame
		for id: String in ["gravekeeper", "furnace_colossus"]:
			_choose("Object", "boss/" + id)
			for action: String in ["idle", "run"]:
				_choose("Action", action)
				await _click("First")
				await _click("Next")
				_check(_lab.frame_index == 1 and not _lab.playing, id + "/" + action + " strict single step")
				await _click("First")
				await process_frame
				await process_frame
				await _check_scroll(id + "_" + action + "_" + str(dimensions.x))
			for key: String in ["Play", "Previous", "Next", "First", "Export"]:
				_check(root.get_visible_rect().encloses((_lab.widgets.controls[key] as Control).get_global_rect()), "controls visible " + key)
			await _click("Export")
	_choose("Category", "玩家")
	_choose("Object", "player/knight")
	await _click("First")
	await process_frame
	await process_frame
	var scroll: ScrollContainer = _lab.widgets.controls["PreviewScroll"]
	_check(scroll.scroll_horizontal == 0 and scroll.scroll_vertical == 0 and _lab.preview.custom_minimum_size == Vector2(280, 160), "small resource resets large scroll/size")
	print("RK075_UI: " + ("failed" if _failed else "passed"))
	_lab.queue_free()
	await process_frame
	quit(1 if _failed else 0)

func _check_scroll(label: String) -> void:
	var frame: Dictionary = _lab.resource["frames"][0]
	var plane: Rect2 = Rect2(Vector2.ZERO, _lab.preview.size)
	var scroll: ScrollContainer = _lab.widgets.controls["PreviewScroll"]
	var one: Rect2 = Rect2(_lab.preview.pivot_at(0) - frame["pivot"], frame["rect"].size)
	var three: Rect2 = Rect2(_lab.preview.pivot_at(1) - frame["pivot"] * 3, frame["rect"].size * 3)
	_check(plane.encloses(one) and plane.encloses(three), label + " full 1x/3x canvas in scroll plane")
	var visible: Rect2 = scroll.get_global_rect()
	_check(visible.encloses(Rect2(_lab.preview.global_position + one.position, one.size)), label + " complete native preview initially visible")
	var maximum: Vector2 = Vector2(scroll.get_h_scroll_bar().max_value, scroll.get_v_scroll_bar().max_value)
	var reachable: Rect2 = Rect2(Vector2.ZERO, maximum)
	_check(reachable.encloses(three), label + " all 3x pixels reachable")
	await _capture(label + "_top")
	if three.end.y > scroll.size.y:
		var before: int = scroll.scroll_vertical
		for i: int in 8:
			for pressed: bool in [true, false]:
				var event: InputEventMouseButton = InputEventMouseButton.new()
				event.position = visible.get_center()
				event.button_index = MOUSE_BUTTON_WHEEL_DOWN
				event.pressed = pressed
				root.push_input(event, true)
		await process_frame
		_check(scroll.scroll_vertical > before, label + " mouse wheel actually scrolls")
	scroll.scroll_horizontal = int(maximum.x)
	scroll.scroll_vertical = int(maximum.y)
	await process_frame
	await process_frame
	var bottom: Vector2 = _lab.preview.global_position + three.end - Vector2.ONE
	_check(visible.has_point(bottom), label + " weapon/feet far corner visible after scrolling")
	await _capture(label + "_bottom")
	print("RK075 scroll ", label, " plane=", plane, " 3x=", three, " visible=", scroll.size, " offset=", Vector2(scroll.scroll_horizontal, scroll.scroll_vertical))

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(_out.path_join("lab_" + label + ".png")) != OK:
		_check(false, "save graphical evidence " + label)

func _choose(key: String, text: String) -> void:
	var option: OptionButton = _lab.widgets.controls[key]
	for i: int in option.item_count:
		if option.get_item_text(i) == text:
			option.select(i)
			option.item_selected.emit(i)
			return
	_check(false, "missing option " + key + "=" + text)

func _click(key: String) -> void:
	var control: Control = _lab.widgets.controls[key]
	# 长Boss名称可能使状态行换行；等待容器布局后才取真实命中位置。
	await process_frame
	await process_frame
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame
	if key in ["First", "Next"]:
		print("RK075 input ", key, " at=", control.get_global_rect(), " frame=", _lab.frame_index, " playing=", _lab.playing)

func _check(value: bool, message: String) -> void:
	_failed = _failed or not value
	print("RK075 UI ", "OK " if value else "FAIL ", message)
