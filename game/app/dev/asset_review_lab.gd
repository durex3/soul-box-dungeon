class_name AssetReviewLab
extends Control
## 独立开发验收台；不驱动 Sim、游戏动画状态或全局时钟。

const CATEGORIES: PackedStringArray = ["", "player", "enemy", "elite", "soul", "pickup", "tag"]
const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0]
var catalog: ReviewCatalog = ReviewCatalog.new()
var widgets: ReviewWidgets = ReviewWidgets.new()
var preview: ReviewCanvas
var current: Dictionary = {}
var resource: Dictionary = {}
var frame_index: int = 0
var playing: bool = false
var speed: float = 1.0
var _elapsed: float = 0.0
var _objects: Array[String] = []
var _object_key: String = ""
var _actions: Array[String] = []
var _action: String = "idle"
var _choices: Array[Dictionary] = []

func _ready() -> void:
	if not OS.is_debug_build():
		hide()
		set_process(false)
		return
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview = widgets.build(self) as ReviewCanvas
	catalog.scan()
	_connect_controls()
	_refresh_objects()
	(widgets.controls["Play"] as Button).grab_focus()

func _connect_controls() -> void:
	_option("Category").item_selected.connect(func(_index: int) -> void: _refresh_objects())
	(widgets.controls["Search"] as LineEdit).text_changed.connect(func(_text: String) -> void: _refresh_objects())
	_option("Object").item_selected.connect(_select_object)
	_option("Action").item_selected.connect(func(index: int) -> void:
		_action = _actions[index]
		_refresh_tiers())
	_option("Tier").item_selected.connect(func(index: int) -> void: _load_choice(index))
	_option("Speed").item_selected.connect(func(index: int) -> void:
		speed = SPEEDS[index]
		_update_display())
	_option("Background").item_selected.connect(func(index: int) -> void:
		preview.background = index
		_update_display())
	_option("Material").item_selected.connect(func(index: int) -> void:
		preview.mode = index
		_update_display())
	for key: String in ["Canvas", "Body", "Pivot", "Baseline", "Target", "Answer"]:
		(widgets.controls[key] as CheckButton).toggled.connect(func(_on: bool) -> void: _update_display())
	(widgets.controls["HideNames"] as CheckButton).toggled.connect(func(_on: bool) -> void: _refresh_objects())
	(widgets.controls["Play"] as Button).pressed.connect(_toggle_play)
	(widgets.controls["Previous"] as Button).pressed.connect(_step.bind(-1))
	(widgets.controls["Next"] as Button).pressed.connect(_step.bind(1))
	(widgets.controls["First"] as Button).pressed.connect(_first)
	(widgets.controls["Export"] as Button).pressed.connect(_export)

func _refresh_objects() -> void:
	var option: OptionButton = _option("Object")
	option.clear()
	_objects.clear()
	var category: String = CATEGORIES[_option("Category").selected]
	var query: String = (widgets.controls["Search"] as LineEdit).text.to_lower()
	for entry: Dictionary in catalog.entries:
		if (not category.is_empty() and entry["category"] != category) or (not query.is_empty() and not str(entry["id"]).contains(query)):
			continue
		var key: String = entry["category"] + "/" + entry["id"]
		if key in _objects:
			continue
		_objects.append(key)
		option.add_item("#%03d" % entry["number"] if _checked("HideNames") else key)
	if _objects.is_empty():
		_clear("无匹配资源；请调整类别 / id 筛选")
		return
	var index: int = maxi(0, _objects.find(_object_key))
	option.select(index)
	_select_object(index)

func _select_object(index: int) -> void:
	_object_key = _objects[index]
	_actions.clear()
	_option("Action").clear()
	for entry: Dictionary in catalog.entries:
		if entry["category"] + "/" + entry["id"] == _object_key and not entry["action"] in _actions:
			_actions.append(entry["action"])
			_option("Action").add_item(entry["action"])
	if not _action in _actions:
		_action = "idle" if "idle" in _actions else _actions[0]
	_option("Action").select(_actions.find(_action))
	_refresh_tiers()

func _refresh_tiers() -> void:
	var old_tier: int = int(current.get("tier", 0))
	_choices.clear()
	_option("Tier").clear()
	var selected: int = 0
	for entry: Dictionary in catalog.entries:
		if entry["category"] + "/" + entry["id"] == _object_key and entry["action"] == _action:
			_choices.append(entry)
			_option("Tier").add_item("T%d" % entry["tier"] if entry["tier"] > 0 else "无品阶")
			if entry["tier"] == old_tier:
				selected = _choices.size() - 1
	_option("Tier").disabled = _choices.size() < 2
	_option("Tier").select(selected)
	_load_choice(selected)

func _load_choice(index: int) -> void:
	current = _choices[index]
	resource = catalog.read_entry(current)
	frame_index = 0
	_elapsed = 0.0
	playing = resource["error"].is_empty() and resource["frames"].size() > 1
	_update_display()

func _clear(message: String) -> void:
	current = {}
	resource = {"error": message, "frames": []}
	playing = false
	frame_index = 0
	_elapsed = 0.0
	_option("Action").clear()
	_option("Tier").clear()
	_update_display()

func _process(delta: float) -> void:
	if not playing:
		return
	_elapsed += delta * speed * 1000.0
	var frames: Array = resource["frames"]
	var previous: int = frame_index
	while _elapsed >= frames[frame_index]["duration"]:
		_elapsed -= frames[frame_index]["duration"]
		if frame_index == frames.size() - 1:
			if _checked("Loop"):
				frame_index = 0
			else:
				playing = false
				_elapsed = 0.0
				break
		else:
			frame_index += 1
	if previous != frame_index or not playing:
		_update_display()

func _toggle_play() -> void:
	if resource.get("frames", []).size() > 1:
		playing = not playing
	_update_display()

func _step(direction: int) -> void:
	playing = false
	_elapsed = 0.0
	var count: int = resource.get("frames", []).size()
	if count > 1:
		frame_index = posmod(frame_index + direction, count) if _checked("Loop") else clampi(frame_index + direction, 0, count - 1)
	_update_display()

func _first() -> void:
	playing = false
	frame_index = 0
	_elapsed = 0.0
	_update_display()

func _update_display() -> void:
	if not is_instance_valid(preview):
		return
	for key: String in ["Canvas", "Body", "Pivot", "Baseline", "Target"]:
		preview.guides[key.to_lower()] = _checked(key)
	var frames: Array = resource.get("frames", [])
	var error: String = resource.get("error", "")
	var valid: bool = error.is_empty() and not frames.is_empty()
	for key: String in ["Play", "Previous", "Next", "First"]:
		(widgets.controls[key] as Button).disabled = not valid or frames.size() == 1
	(widgets.controls["Play"] as Button).text = "暂停" if playing else "播放"
	if not valid:
		preview.present(null, {}, "资源不可用")
		_label("State").text = "已停止 · 特效：未接入"
		_label("Details").text = error
		return
	var frame: Dictionary = frames[frame_index]
	var identity: String = "#%03d" % current["number"] if _checked("HideNames") else current["id"]
	var action: String = current["action"]
	var state: String = "单帧" if frames.size() == 1 else ("播放中" if playing else "已暂停")
	preview.present(resource["texture"], frame, identity + " · " + action)
	var tier: String = " T%d" % current["tier"] if current["tier"] > 0 else ""
	_label("State").text = "%s · %s%s · %s · 帧 %d/%d（0基）· %sms · %s× · 特效：未接入" % [identity, action, tier, state, frame_index, frames.size() - 1, frame["duration"], speed]
	var info: String = "画布 %d×%d · %d帧\npivot %s\n主体框：%s" % [frame["rect"].size.x, frame["rect"].size.y, frames.size(), frame["pivot"], str(frame.get("body_rect", "不可用"))]
	if not _checked("HideNames") or _checked("Answer"):
		info += "\n编号答案：%s / %s\nPNG：%s\nJSON：%s" % [current["category"], current["id"], resource["image_path"], current["path"]]
	else:
		info += "\n编号答案已隐藏"
	_label("Details").text = info
	_label("Details").tooltip_text = info

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build() or get_viewport().gui_get_focus_owner() is LineEdit:
		return
	for control: Control in widgets.controls.values():
		if control is OptionButton and control.get_popup().visible:
			return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: _toggle_play()
			KEY_LEFT: _step(-1)
			KEY_RIGHT: _step(1)
			KEY_HOME: _first()
			_: return
		get_viewport().set_input_as_handled()

func _export() -> void:
	var button: Button = widgets.controls["Export"]
	button.disabled = true
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path("user://review/")
	var code: Error = DirAccess.make_dir_recursive_absolute(directory)
	var file: String = directory.path_join("review_%s_%d.png" % [Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_msec()])
	if code == OK:
		code = get_viewport().get_texture().get_image().save_png(file)
	if code == OK:
		print("RK119 screenshot: %s | resource=%s | frame=%d | speed=%s" % [file, current.get("path", "无"), frame_index, speed])
		_label("Output").text = "已导出 user://review/ · 完整路径见输出"
		_label("Output").tooltip_text = file
	else:
		_label("Output").text = "导出失败：%s（错误%d）" % [directory, code]
	button.disabled = false

func _option(key: String) -> OptionButton:
	return widgets.controls[key] as OptionButton

func _label(key: String) -> Label:
	return widgets.controls[key] as Label

func _checked(key: String) -> bool:
	return (widgets.controls[key] as CheckButton).button_pressed
