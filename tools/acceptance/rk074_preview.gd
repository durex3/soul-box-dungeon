extends SceneTree

const PREFIX: String = "res://assets/sprites/greybox/rk074/"
class Board:
	extends Node2D
	var captions: Array[Dictionary] = []
	var boxes: Array[Rect2] = []
	var background: Color = Color("#1C1B26")
	func _draw() -> void:
		draw_rect(Rect2(0,0,640,360),background)
		for item: Dictionary in captions:
			draw_string(ThemeDB.fallback_font,item["at"],item["text"],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#A39DB8"))
		for box: Rect2 in boxes:
			draw_rect(box,Color("#7A7393"),false,1.0)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var tags: Dictionary = {}
	for row: Dictionary in SoulTable.ROWS:
		tags[str(row.get("id"))] = row.get("tags")
	print("RK074_TABLE " + JSON.stringify(tags))
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../art/source/rk074/manifest.json")))
		await _sheet(manifest["assets"],args[0],false)
		await _sheet(manifest["assets"],args[0],true)
		await _icons(manifest["assets"],args[0],false)
		await _icons(manifest["assets"],args[0],true)
	print("RK074_PROBE: passed")
	quit()

func _viewport() -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(640,360)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(view)
	return view

func _sprite(entry: Dictionary, at: Vector2, board: Board) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(PREFIX+entry["file"])
	sprite.centered = false
	sprite.position = at-Vector2(entry["pivot"]["x"],entry["pivot"]["y"])
	board.add_child(sprite)
	return sprite

func _sheet(entries: Array, out: String, guides: bool) -> void:
	var view: SubViewport = _viewport()
	var board: Board = Board.new()
	view.add_child(board)
	for i: int in 48:
		var entry: Dictionary = entries[i]
		var tier: int = entry["tier"]
		if i<4: board.captions.append({"at":Vector2(184+(tier-1)*92,10),"text":"T%d" % tier})
		var at: Vector2 = Vector2(190+(tier-1)*92,22+(i/4)*24)
		if tier==1: board.captions.append({"at":Vector2(8,at.y+3),"text":entry["id"]})
		var sprite: Sprite2D = _sprite(entry,at,board)
		if guides:
			var size: Dictionary = entry["canvas_size"]
			var body: Dictionary = entry["body_rect"]
			board.boxes.append(Rect2(sprite.position-Vector2.ONE,Vector2(size["w"],size["h"])+Vector2(2,2)))
			board.boxes.append(Rect2(sprite.position+Vector2(body["x"],body["y"]),Vector2(body["w"],body["h"])))
			board.captions.append({"at":at+Vector2(12,-6),"text":"%d/%d" % [size["w"],body["w"]]})
	for i: int in range(48,60):
		var entry: Dictionary = entries[i]
		var at: Vector2 = Vector2(25+(i-48)*52,330)
		_sprite(entry,at,board)
		board.captions.append({"at":at+Vector2(-12,20),"text":"%02d" % (i-47)})
	board.queue_redraw()
	await _capture(view,out,"guides" if guides else "all",true)
	view.queue_free()
	await process_frame

func _icons(entries: Array, out: String, mono: bool) -> void:
	var view: SubViewport = _viewport()
	var board: Board = Board.new()
	board.background = Color("#2E2A3A")
	view.add_child(board)
	var shader: Shader = Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){vec4 c=texture(TEXTURE,UV); float l=" + ("0.65" if mono else "dot(c.rgb,vec3(0.2126,0.7152,0.0722))") + "; COLOR=vec4(vec3(l),c.a);}"
	for i: int in 7:
		var at: Vector2 = Vector2(60+i*84,180)
		var sprite: Sprite2D = _sprite(entries[53+i],at,board)
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = shader
		sprite.material = material
		board.captions.append({"at":at+Vector2(-4,24),"text":"%02d" % (i+1)})
	board.queue_redraw()
	await _capture(view,out,"icons_shape" if mono else "icons_gray",false)
	view.queue_free()
	await process_frame

func _capture(view: SubViewport, out: String, name: String, triple: bool) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	if view.get_texture().get_image().save_png(out.path_join(name+"_1x.png"))!=OK: push_error("RK074 save PNG failed")
	if triple:
		var large: SubViewport = SubViewport.new()
		large.size = Vector2i(1920,1080)
		large.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(large)
		var screen: TextureRect = TextureRect.new()
		screen.texture = view.get_texture()
		screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		screen.size = Vector2(1920,1080)
		large.add_child(screen)
		await process_frame
		await RenderingServer.frame_post_draw
		if large.get_texture().get_image().save_png(out.path_join(name+"_3x.png"))!=OK: push_error("RK074 save 3x failed")
		large.queue_free()
