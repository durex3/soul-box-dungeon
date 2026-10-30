extends SceneTree

const ROOT: String = "res://assets/sprites/greybox/rk073/"
const FLOOR: Color = Color("#1C1B26")
var _entries: Array = []
var _out: String

class Backdrop:
	extends Node2D
	var shade: Color
	var captions: Array[Dictionary] = []
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 640, 360), shade)
		for caption: Dictionary in captions:
			draw_string(ThemeDB.fallback_font, caption["at"], caption["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#A39DB8"))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("rk073_preview needs output directory")
		quit(1)
		return
	_out = args[0]
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../art/source/rk073/manifest.json")))
	_entries = manifest["assets"]
	for page: int in 2:
		await _page(page, false)
		await _page(page, true)
	await _motion()
	print("RK073_PREVIEW: passed")
	quit()

func _viewport() -> SubViewport:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	return viewport

func _page(page: int, silhouette: bool) -> void:
	var viewport: SubViewport = _viewport()
	var background: Backdrop = Backdrop.new()
	background.shade = Color("#7A7A7A") if silhouette else FLOOR
	viewport.add_child(background)
	var black: Shader = Shader.new()
	black.code = "shader_type canvas_item; void fragment(){vec4 c=texture(TEXTURE,UV); float shadow=step(distance(c.rgb,vec3(11.,10.,18.)/255.),0.001); COLOR=vec4(0.,0.,0.,c.a*(1.-shadow));}"
	for cell: int in 9:
		var index: int = page * 9 + cell
		var idle: Dictionary = _entries[index * 2]
		var base: Vector2 = Vector2(8 + (cell % 3) * 210, 8 + (cell / 3) * 116)
		var title: String = "%02d" % (index + 1)
		if not silhouette:
			title += " " + idle["id"] + (" elite" if idle["elite"] else "")
		background.captions.append({"at": base + Vector2(0, 12), "text": title})
		for action: int in 2:
			var entry: Dictionary = _entries[index * 2 + action]
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + str(entry["file"]).get_basename() + ".json"))
			var n: int = entry["frame_size"]["w"]
			for frame_index: int in 2:
				var frame: Dictionary = data["frames"][frame_index]["frame"]
				var sprite: Sprite2D = Sprite2D.new()
				sprite.texture = load(ROOT + entry["file"])
				sprite.region_enabled = true
				sprite.region_rect = Rect2(frame["x"], frame["y"], frame["w"], frame["h"])
				sprite.centered = false
				sprite.position = base + Vector2((action * 2 + frame_index) * (n + 3), 88 - entry["pivot"]["y"])
				if silhouette:
					var material: ShaderMaterial = ShaderMaterial.new()
					material.shader = black
					sprite.material = material
				background.add_child(sprite)
	background.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var name: String = ("silhouette" if silhouette else "poses") + "_%d" % (page + 1)
	var error: Error = viewport.get_texture().get_image().save_png(_out.path_join(name + "_1x.png"))
	if error != OK:
		push_error("preview PNG save failed")
	if not silhouette:
		await _triple(viewport, name)
	viewport.queue_free()
	await process_frame

func _triple(source: SubViewport, name: String) -> void:
	var outer: SubViewport = SubViewport.new()
	outer.size = Vector2i(1920, 1080)
	outer.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(outer)
	var screen: TextureRect = TextureRect.new()
	screen.texture = source.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.size = Vector2(1920, 1080)
	outer.add_child(screen)
	await process_frame
	await RenderingServer.frame_post_draw
	if outer.get_texture().get_image().save_png(_out.path_join(name + "_3x.png")) != OK:
		push_error("3x preview save failed")
	outer.queue_free()

func _motion() -> void:
	var viewport: SubViewport = _viewport()
	var background: Backdrop = Backdrop.new()
	background.shade = FLOOR
	viewport.add_child(background)
	for index: int in 18:
		var base: Vector2 = Vector2(4 + (index % 6) * 106, 4 + (index / 6) * 116)
		background.captions.append({"at": base + Vector2(0, 12), "text": "%02d idle / run" % (index + 1)})
		for action: int in 2:
			var entry: Dictionary = _entries[index * 2 + action]
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + str(entry["file"]).get_basename() + ".json"))
			var frames: SpriteFrames = SpriteFrames.new()
			frames.add_animation("preview")
			frames.set_animation_speed("preview", 1000.0 / data["frames"][0]["duration"])
			for item: Dictionary in data["frames"]:
				var region: Dictionary = item["frame"]
				var texture: AtlasTexture = AtlasTexture.new()
				texture.atlas = load(ROOT + entry["file"])
				texture.region = Rect2(region["x"], region["y"], region["w"], region["h"])
				frames.add_frame("preview", texture)
			var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
			sprite.sprite_frames = frames
			sprite.centered = false
			sprite.position = base + Vector2(action * 52 + 24 - entry["pivot"]["x"], 88 - entry["pivot"]["y"])
			background.add_child(sprite)
			sprite.play("preview")
	background.queue_redraw()
	# Real engine playback at source millisecond timing; two samples document movement.
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(_out.path_join("motion_a.png"))
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(_out.path_join("motion_b.png"))
	viewport.queue_free()
