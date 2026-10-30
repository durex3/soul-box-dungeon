class_name ReviewWidgets
extends RefCounted
## 用标准容器构建验收台控件，保持键盘焦点和滚动布局。

var controls: Dictionary = {}

## 创建紧凑的响应式界面并返回预览挂载区。
func build(root: Control) -> Control:
	root.theme = Theme.new()
	root.theme.default_font_size = 11
	root.add_theme_color_override("font_color", Color("#E1DCEB"))
	var background: ColorRect = ColorRect.new()
	background.color = Color("#12121C")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: MarginContainer = MarginContainer.new()
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	var layout: VBoxContainer = VBoxContainer.new()
	margin.add_child(layout)
	_label(layout, "Title", "资源验收台 · DEBUG     空格 播放/暂停   ←/→ 单步   Home 首帧")
	var main: HBoxContainer = HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(main)
	var preview: Control = ReviewCanvas.new()
	preview.custom_minimum_size = Vector2(280, 160)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var preview_scroll: ScrollContainer = ScrollContainer.new()
	preview_scroll.custom_minimum_size = Vector2(280, 160)
	preview_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_scroll.tooltip_text = "大图保持1×/3×；使用右侧/底部滚动条查看全部画布"
	_register(main, "PreviewScroll", preview_scroll)
	preview_scroll.add_child(preview)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.x = 214
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	var side: VBoxContainer = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(side)
	_label(side, "ObjectTitle", "对象 / 角色")
	_choice(side, "Category", ["全部类别", "玩家", "普通敌人", "精英", "魂匣", "拾取物", "标签", "Boss"])
	var search: LineEdit = LineEdit.new()
	search.placeholder_text = "按 id 筛选"
	_register(side, "Search", search)
	_choice(side, "Object", [])
	_label(side, "ActionTitle", "动作 / 品阶")
	_choice(side, "Action", [])
	_choice(side, "Tier", ["全部品阶", "T1", "T2", "T3", "T4"])
	_label(side, "EffectTitle", "特效")
	var effect: OptionButton = _choice(side, "Effect", ["未接入"])
	effect.disabled = true
	_label(side, "Geometry", "碰撞 / 攻击范围：不可用（无数据）")
	_choice(side, "Background", ["区域1地面 #1C1B26", "灰底", "透明棋盘"])
	_choice(side, "Material", ["原色", "灰度", "纯黑剪影（排除投影）"])
	for pair: Array in [["Canvas", "画布框", false], ["Body", "主体框（有数据时）", false], ["Pivot", "pivot 十字", true], ["Baseline", "对齐基线", true], ["Target", "展示靶标记", false], ["HideNames", "隐藏名称 / 编号盲看", false], ["Answer", "侧栏显示编号答案", false]]:
		_check(side, pair[0], pair[1], pair[2])
	_label(side, "Details", "")
	var bottom: VBoxContainer = VBoxContainer.new()
	layout.add_child(bottom)
	var row: HBoxContainer = HBoxContainer.new()
	bottom.add_child(row)
	for pair: Array in [["Play", "播放"], ["Previous", "上一帧"], ["Next", "下一帧"], ["First", "首帧"]]:
		_button(row, pair[0], pair[1])
	_check(row, "Loop", "循环", true)
	_choice(row, "Speed", ["0.25×", "0.5×", "1×", "2×"]).select(2)
	_button(row, "Export", "导出当前画面")
	_label(bottom, "State", "")
	_label(bottom, "Output", "输出：user://review/（截图需人工判断）")
	return preview

func _register(parent: Node, key: String, control: Control) -> void:
	control.name = key
	parent.add_child(control)
	controls[key] = control

func _label(parent: Node, key: String, text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_register(parent, key, label)
	return label

func _choice(parent: Node, key: String, items: Array) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.fit_to_longest_item = false
	option.custom_minimum_size.x = 48
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item: String in items:
		option.add_item(item)
	_register(parent, key, option)
	return option

func _button(parent: Node, key: String, text: String) -> void:
	var button: Button = Button.new()
	button.text = text
	_register(parent, key, button)

func _check(parent: Node, key: String, text: String, enabled: bool) -> void:
	var check: CheckButton = CheckButton.new()
	check.text = text
	check.button_pressed = enabled
	_register(parent, key, check)
