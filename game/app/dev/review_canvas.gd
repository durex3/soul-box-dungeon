class_name ReviewCanvas
extends Control
## 纯展示平面：纹理切片、材质和参考线均不写回生产资产。

var background: int = 0
var mode: int = 0
var guides: Dictionary = {"canvas": false, "body": false, "pivot": true, "baseline": true, "target": false}
var caption: String = ""
var frame: Dictionary = {}
var _sprites: Array[Sprite2D] = []
var _texture: Texture2D
var _shader: Shader = Shader.new()
var _overlay: Control
# 只读调试证据：记录本帧实际draw_string参数，覆盖检查不猜测字体继承。
var text_draws: Array[Dictionary] = []

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shader.code = """shader_type canvas_item;
uniform int mode = 0;
uniform bool exclude_shadow = false;
void fragment() {
 vec4 c = texture(TEXTURE, UV);
 if (mode == 1) { c.rgb = vec3(dot(c.rgb, vec3(0.2126, 0.7152, 0.0722))); }
 if (mode == 2) { float shadow = exclude_shadow ? step(distance(c.rgb, vec3(11.0,10.0,18.0)/255.0), 0.001) : 0.0; c = vec4(vec3(0.0),c.a*(1.0-shadow)); }
 COLOR = c;
}"""
	for factor: int in [1, 3]:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.centered = false
		sprite.region_enabled = true
		sprite.region_filter_clip_enabled = true
		sprite.scale = Vector2.ONE * factor
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = _shader
		sprite.material = mat
		add_child(sprite)
		_sprites.append(sprite)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_guides)
	resized.connect(_refresh)

## 将同一帧提交给 1× 和 3×；空帧立即清除旧图。
func present(texture: Texture2D, current: Dictionary, text: String) -> void:
	_texture = texture
	frame = current
	caption = text
	# 小资源维持原布局；大画布留出独立的完整1×区及可滚动3×区。
	custom_minimum_size = Vector2(280, 160)
	if not frame.is_empty() and frame["rect"].size.y > 48:
		var dimensions: Vector2 = frame["rect"].size
		custom_minimum_size = Vector2(dimensions.x * 4 + 48, dimensions.y * 3 + 80)
	_refresh()

## 返回预览中 pivot 的整数位置，便于对照实际截图。
func pivot_at(index: int) -> Vector2:
	if not frame.is_empty() and frame["rect"].size.y > 48:
		var origin: Vector2 = Vector2(16 if index == 0 else frame["rect"].size.x + 32, 60)
		return origin + frame["pivot"] * (1 if index == 0 else 3)
	return Vector2(floor(size.x * (0.27 if index == 0 else 0.72)), floor(size.y * 0.63))

func _refresh() -> void:
	for i: int in _sprites.size():
		var sprite: Sprite2D = _sprites[i]
		sprite.visible = not frame.is_empty()
		if frame.is_empty():
			sprite.texture = null
			continue
		var factor: int = 1 if i == 0 else 3
		sprite.texture = _texture
		sprite.region_rect = frame["rect"]
		sprite.position = pivot_at(i) - frame["pivot"] * factor
		(sprite.material as ShaderMaterial).set_shader_parameter("mode", mode)
		(sprite.material as ShaderMaterial).set_shader_parameter("exclude_shadow", frame.get("exclude_shadow", false))
	queue_redraw()
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()

func _draw() -> void:
	text_draws.clear()
	var area: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(area, [Color("#1C1B26"), Color("#777777"), Color("#42424B")][background])
	if background == 2:
		for y: int in range(0, int(size.y), 8):
			for x: int in range(0, int(size.x), 8):
				if (x / 8 + y / 8) % 2 == 0:
					draw_rect(Rect2(x, y, 8, 8), Color("#60606B"))
	elif background == 0:
		for x: int in range(0, int(size.x), 16):
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.06))
		for y: int in range(0, int(size.y), 16):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.06))
	_text(Vector2(8, 17), caption)

func _draw_guides() -> void:
	for i: int in 2:
		var factor: int = 1 if i == 0 else 3
		var pivot: Vector2 = pivot_at(i)
		_draw_text(_overlay, get_theme_font("font"), Vector2(pivot.x - 12, 36), "%d× nearest" % factor)
		if frame.is_empty():
			continue
		var origin: Vector2 = pivot - frame["pivot"] * factor
		if guides["baseline"]:
			_overlay.draw_line(Vector2(pivot.x - 65, pivot.y), Vector2(pivot.x + 65, pivot.y), Color("#7A7393"))
		if guides["canvas"]:
			_overlay.draw_rect(Rect2(origin, frame["rect"].size * factor), Color("#33CCFF"), false)
		if guides["body"] and frame.has("body_rect"):
			var body: Rect2 = frame["body_rect"]
			_overlay.draw_rect(Rect2(origin + body.position * factor, body.size * factor), Color("#E5B84A"), false)
		if guides["pivot"]:
			_overlay.draw_line(pivot - Vector2(4, 0), pivot + Vector2(4, 0), Color("#FF7697"))
			_overlay.draw_line(pivot - Vector2(0, 4), pivot + Vector2(0, 4), Color("#FF7697"))
	if guides["target"]:
		var target: Vector2 = Vector2(floor(size.x / 2), floor(size.y - 25))
		_overlay.draw_arc(target, 6, 0, TAU, 24, Color("#A39DB8"))
		_overlay.draw_line(target - Vector2(9, 0), target + Vector2(9, 0), Color("#A39DB8"))
		_draw_text(_overlay, get_theme_font("font"), target + Vector2(12, 3), "展示靶")

func _text(at: Vector2, text: String) -> void:
	_draw_text(self, get_theme_font("font"), at, text)

func _draw_text(canvas: CanvasItem, font: Font, at: Vector2, text: String) -> void:
	canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#E1DCEB"))
	text_draws.append({"text": text, "font": font, "size": 12,
		"rect": Rect2(at - Vector2(0, font.get_ascent(12)), font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12))})
