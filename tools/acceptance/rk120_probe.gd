extends SceneTree
## Graphical synthetic input, actual font/draw arguments and text geometry evidence.

const FONT_PATH: String = "res://assets/fonts/fusion-pixel-12px-zh_hans.woff2"
var failures: Array[String] = []
var texts: Dictionary = {}
var codepoints: Dictionary = {}
var records: Dictionary = {}
var out: String
var mode: String
var lab: AssetReviewLab

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		print("RK120 FAIL " + message)

func _font_text(font: Font, size: int, text: String, source: String) -> void:
	if text.is_empty():
		return
	texts[text] = true
	var missing: Array[String] = []
	for character: String in text:
		var cp: int = character.unicode_at(0)
		if cp >= 32:
			codepoints["U+%04X" % cp] = character
			if not font.has_char(cp):
				missing.append("U+%04X %s" % [cp, character])
	_check(missing.is_empty(), source + " missing " + str(missing))
	_check(font is FontFile and font.resource_path == FONT_PATH, source + " actual font " + font.resource_path)
	_check(size == 12, source + " size=" + str(size))
	if font is FontFile:
		_check(not font.allow_system_fallback and font.antialiasing == TextServer.FONT_ANTIALIASING_NONE and font.subpixel_positioning == TextServer.SUBPIXEL_POSITIONING_DISABLED and font.hinting == TextServer.HINTING_NONE and font.oversampling == 1.0, source + " raster settings")
	records[source + "|" + text] = {"source": source, "text": text, "font": font.resource_path, "size": size}

func _audit(scene: Node) -> void:
	for c: Node in scene.find_children("*", "Control", true, false):
		var control: Control = c as Control
		var font: Font = control.get_theme_font("font")
		var size: int = control.get_theme_font_size("font_size")
		if control is Label or control is Button or control is LineEdit:
			_font_text(font, size, control.text, str(control.get_path()))
			_geometry(control)
		if control is LineEdit:
			_font_text(font, size, control.placeholder_text, "placeholder:" + str(control.get_path()))
		if not control.tooltip_text.is_empty():
			# TooltipLabel is a separate themed type; audit its resolved font too.
			_font_text(control.get_theme_font("font", "TooltipLabel"), control.get_theme_font_size("font_size", "TooltipLabel"), control.tooltip_text, "tooltip:" + str(control.get_path()))
		if control is OptionButton:
			var popup: PopupMenu = control.get_popup()
			for i: int in popup.item_count:
				_font_text(popup.get_theme_font("font"), popup.get_theme_font_size("font_size"), popup.get_item_text(i), "popup:" + control.name)
				if popup.visible:
					_check(popup.get_theme_font("font").get_string_size(popup.get_item_text(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 24 <= popup.size.x, "popup geometry " + popup.get_item_text(i))
	if scene is AssetReviewLab:
		_check(not scene.preview.text_draws.is_empty(), "actual draw calls present")
		var drawn: Array[String] = []
		for draw: Dictionary in scene.preview.text_draws:
			drawn.append(draw.text)
		_check("1× nearest" in drawn and "3× nearest" in drawn, "actual scale label calls present")
		if scene.preview.guides.target:
			_check("展示靶" in drawn, "actual target draw call present")
		for draw: Dictionary in scene.preview.text_draws:
			_font_text(draw.font, draw.size, draw.text, "draw:" + draw.text)
			_check(Rect2(Vector2.ZERO, scene.preview.size).encloses(draw.rect), "draw geometry " + draw.text + " " + str(draw.rect))
		for key: String in ["Play", "Previous", "Next", "First", "Loop", "Speed", "Export", "State", "Output"]:
			_check(root.get_visible_rect().encloses(scene.widgets.controls[key].get_global_rect()), "viewport " + key)

func _geometry(c: Control) -> void:
	var font: Font = c.get_theme_font("font")
	var fs: int = c.get_theme_font_size("font_size")
	if c is Label:
		var h: float = c.get_line_count() * c.get_line_height()
		_check(h <= c.size.y + 0.01, "geometry height " + c.name)
		if c.autowrap_mode == TextServer.AUTOWRAP_OFF:
			_check(font.get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= c.size.x + 0.01, "geometry width " + c.name)
	elif c is Button and not c is OptionButton:
		var style: StyleBox = c.get_theme_stylebox("normal")
		var width: float = font.get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + style.get_minimum_size().x
		if c is CheckButton:
			width += c.get_theme_icon("checked").get_width() + c.get_theme_constant("h_separation")
		_check(width <= c.size.x + 0.01, "geometry button " + c.name)
	if c.get_parent() is VBoxContainer or c.get_parent() is HBoxContainer:
		for other: Node in c.get_parent().get_children():
			if other is Control and other != c and other.is_visible_in_tree():
				_check(not c.get_rect().intersects(other.get_rect()), "geometry overlap " + c.name + "/" + other.name)

func _settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _capture(name: String, scene: Node) -> void:
	await _settle()
	_audit(scene)
	_check(root.get_texture().get_image().save_png(out.path_join(name + ".png")) == OK, "capture " + name)

func _choose(key: String, text: String) -> void:
	var option: OptionButton = lab.widgets.controls[key]
	for i: int in option.item_count:
		if option.get_item_text(i) == text:
			option.select(i)
			option.item_selected.emit(i)
			return
	_check(false, "choice " + key + "=" + text)

func _click(c: Control) -> void:
	var parent: Node = c.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(c)
		parent = parent.get_parent()
	await _settle()
	var at: Vector2 = c.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _settle()

func _tooltip_labels(node: Node) -> int:
	var count: int = 0
	if node is Label and node.is_visible_in_tree() and node.text.contains("大图保持"):
		_font_text(node.get_theme_font("font"), node.get_theme_font_size("font_size"), node.text, "actual TooltipLabel")
		_geometry(node)
		count += 1
	for child: Node in node.get_children(true):
		count += _tooltip_labels(child)
	return count

func _tooltip() -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = lab.widgets.controls.PreviewScroll.get_global_rect().get_center()
	root.push_input(motion, true)
	await create_timer(0.8).timeout
	await _settle()
	_check(_tooltip_labels(root) > 0, "actual tooltip rendered")
	await _capture("review_tooltip", lab)

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	out = args[0]
	mode = args[1]
	root.size = Vector2i(640, 360)
	root.content_scale_size = root.size
	root.grab_focus()
	await create_timer(0.15).timeout
	if mode.begins_with("player"):
		await _player()
	else:
		await _review()
	var report: Dictionary = {"mode": mode, "synthetic_input": true, "texts": texts.keys(), "codepoints": codepoints, "actual_fonts": records.values(), "failures": failures}
	var file: FileAccess = FileAccess.open(out.path_join(mode + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("RK120_PROBE: " + ("passed" if failures.is_empty() else "failed"))
	quit(0 if failures.is_empty() else 1)

func _review() -> void:
	lab = (load("res://app/dev/asset_review_lab.tscn") as PackedScene).instantiate() as AssetReviewLab
	root.add_child(lab)
	await _settle()
	if mode == "review_unbound":
		lab.theme = null
	if mode == "review_target_default":
		(lab.widgets.controls.Target as CheckButton).button_pressed = true
	await _capture(mode + "_cold", lab)
	if mode != "review" and mode != "review_bad":
		lab.queue_free()
		await process_frame
		return
	for dimensions: Vector2i in [Vector2i(640, 360), Vector2i(1280, 720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		if dimensions.x == 1280:
			lab.queue_free()
			await process_frame
			lab = (load("res://app/dev/asset_review_lab.tscn") as PackedScene).instantiate() as AssetReviewLab
			root.add_child(lab)
		await _capture("review_" + str(dimensions.x) + "_cold", lab)
		await _click(lab.widgets.controls.Category)
		if not (lab.widgets.controls.Category as OptionButton).get_popup().visible:
			_check(lab.widgets.controls.Category.has_focus(), "menu mouse focus hit")
			for pressed: bool in [true, false]:
				var key: InputEventKey = InputEventKey.new()
				key.keycode = KEY_SPACE
				key.pressed = pressed
				root.push_input(key, true)
		await _settle()
		_check((lab.widgets.controls.Category as OptionButton).get_popup().visible, "menu synthetic mouse hit")
		await _capture("review_" + str(dimensions.x) + "_menu", lab)
		(lab.widgets.controls.Category as OptionButton).get_popup().hide()
		if mode == "review" and dimensions.x == 640:
			await _tooltip()
		for category: String in ["玩家", "普通敌人", "精英", "魂匣", "拾取物", "标签", "Boss", "全部类别"]:
			_choose("Category", category)
			await _settle()
			_audit(lab)
			_check((lab.widgets.controls.Object as OptionButton).item_count > 0, "nonempty category " + category)
		_choose("Object", "player/knight")
		_choose("Action", "run")
		if mode == "review_bad":
			_check(not lab.resource.error.is_empty() and not lab.playing, "bad metadata visible/stopped")
			_check((lab.widgets.controls.Details as Label).text.contains("chr_knight_run.json"), "full bad filename")
			var sidebar: ScrollContainer = lab.widgets.controls.Details.get_parent().get_parent()
			sidebar.ensure_control_visible(lab.widgets.controls.Details)
			await _capture("review_" + str(dimensions.x) + "_error", lab)
			_choose("Object", "player/alchemist")
			_check(lab.resource.error.is_empty(), "bad metadata other object recovery")
			continue
		for action: String in ["idle", "run"]:
			_choose("Action", action)
			await _settle()
			_audit(lab)
		await _click(lab.widgets.controls.First)
		await _click(lab.widgets.controls.Next)
		_check(lab.frame_index == 1 and not lab.playing, "step hit")
		await _click(lab.widgets.controls.Play)
		_check(lab.playing, "play hit")
		await _click(lab.widgets.controls.Play)
		_check(not lab.playing, "pause hit")
		for speed: String in ["0.25×", "0.5×", "1×", "2×"]:
			_choose("Speed", speed)
			await _settle()
			_audit(lab)
		for material: String in ["原色", "灰度", "纯黑剪影（排除投影）"]:
			_choose("Material", material)
			for background: String in ["区域1地面 #1C1B26", "灰底", "透明棋盘"]:
				_choose("Background", background)
				await _settle()
				_audit(lab)
		for key: String in ["Canvas", "Body", "Target"]:
			if not lab.widgets.controls[key].button_pressed:
				await _click(lab.widgets.controls[key])
		_check(lab.preview.guides.target, "target actual click hit")
		await _capture("review_" + str(dimensions.x) + "_target", lab)
		_choose("Object", "soul/fireball")
		for tier: int in range(1, 5):
			_choose("Tier", "T%d" % tier)
			await _settle()
			_audit(lab)
		await _click(lab.widgets.controls.HideNames)
		_check(not lab.preview.caption.contains("fireball"), "blind names")
		await _click(lab.widgets.controls.Answer)
		_check(lab.widgets.controls.Details.text.contains("fireball"), "answer hit")
		await _click(lab.widgets.controls.Answer)
		await _click(lab.widgets.controls.HideNames)
		await _click(lab.widgets.controls.Export)
		_check(lab.widgets.controls.Output.text.contains("已导出"), "export hit")
		var sidebar: ScrollContainer = lab.widgets.controls.Details.get_parent().get_parent()
		sidebar.ensure_control_visible(lab.widgets.controls.Details)
		await _capture("review_" + str(dimensions.x) + "_long", lab)
		var search: LineEdit = lab.widgets.controls.Search
		await _click(search)
		search.grab_focus()
		for character: String in "骑士测试":
			var event: InputEventKey = InputEventKey.new()
			event.unicode = character.unicode_at(0)
			event.pressed = true
			root.push_input(event, true)
		_check(search.text == "骑士测试", "actual Unicode key input")
		await _capture("review_" + str(dimensions.x) + "_input", lab)
		search.clear()
		search.text_changed.emit("")
		search.release_focus()
		_choose("Category", "全部类别")
		_choose("Object", "player/knight")
		_choose("Action", "idle")
		await _capture("review_" + str(dimensions.x) + "_returned", lab)
	lab.queue_free()
	await process_frame

func _player() -> void:
	var scene: PlayerMovementLab = (load("res://app/dev/player_movement_lab.tscn") as PackedScene).instantiate() as PlayerMovementLab
	root.add_child(scene)
	await _settle()
	scene.driver.set_paused(true)
	if mode == "player_unbound":
		scene._status.get_parent().theme = null
	if mode == "player_clipped":
		scene._status.clip_text = true
		scene._status.get_parent().size.x = 16
	await _capture(mode + "_cold", scene)
	if mode != "player":
		scene.queue_free()
		await process_frame
		return
	for dimensions: Vector2i in [Vector2i(640, 360), Vector2i(1280, 720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for index: int in [0, 1]:
			var button: Button = scene._status.get_parent().get_child(index + 2)
			await _click(button)
			_check(scene.sim.state.player.move_speed_bonus == index * 0.5, "rebuild mouse hit")
			var before: Vector2 = scene.sim.state.player.position
			var event: InputEventKey = InputEventKey.new()
			event.physical_keycode = KEY_D
			event.pressed = true
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			await create_timer(0.15).timeout
			event.pressed = false
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			scene.driver.set_paused(true)
			_check(scene.steps > 0 and scene.sim.state.player.position.x > before.x, "real driver/collector movement")
			_check(scene._status.text.contains(str(scene.steps)) and scene._status.text.contains(str(scene.sim.state.player.position)), "updated status")
			for c: Control in scene._status.get_parent().get_children():
				_check(root.get_visible_rect().encloses(c.get_global_rect()), "player viewport " + c.name)
			await _capture("player_%d_bonus%d" % [dimensions.x, index * 50], scene)
	scene.queue_free()
	await process_frame
