extends RefCounted

const FONT_PATH: String = "res://assets/fonts/fusion-pixel-12px-zh_hans.woff2"

## 核对真正生效的字体字形和控件几何；不把UTF-8字符串正确当作字体覆盖。
static func errors(root: Control) -> PackedStringArray:
	var result: PackedStringArray = []
	var rectangles: Array[Rect2] = []
	for control: Control in root.find_children("*", "Control", true, false):
		if not control is Button and not control is Label:
			continue
		var text: String = control.text
		var font: Font = control.get_theme_font("font")
		var size: int = control.get_theme_font_size("font_size")
		if font.resource_path != FONT_PATH or not font is FontFile or font.allow_system_fallback:
			result.append("font binding/fallback: " + text)
		if size != 12:
			result.append("font size: " + text)
		for character: String in text:
			if character.unicode_at(0) >= 32 and not font.has_char(character.unicode_at(0)):
				result.append("missing glyph U+%04X %s in %s" % [character.unicode_at(0), character, text])
		var required: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		var available: Vector2 = control.size
		if control is Button:
			available -= control.get_theme_stylebox("normal").get_minimum_size()
			for rect: Rect2 in rectangles:
				if rect.intersects(control.get_global_rect()):
					result.append("button overlap: " + text)
			rectangles.append(control.get_global_rect())
		if required.x > available.x + 0.01 or required.y > available.y + 0.01:
			result.append("text clipping: " + text)
		if not root.get_global_rect().encloses(control.get_global_rect()):
			result.append("outside viewport: " + text)
	return result
