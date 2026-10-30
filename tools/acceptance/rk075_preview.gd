extends SceneTree
## 实际 Godot 渲染姿态和盲看剪影；预览不读取 art 源。

class Board:
	extends Node2D
	var captions: Array[Dictionary] = []
	var grey: bool = false
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 640, 360), Color("#777777") if grey else Color("#1C1B26"))
		for item: Dictionary in captions:
			draw_string(ThemeDB.fallback_font, item["at"], item["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#E1DCEB"))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var catalog: ReviewCatalog = ReviewCatalog.new()
	catalog.scan()
	var answers: Dictionary = {}
	for blind: bool in [false, true]:
		var view: SubViewport = SubViewport.new()
		view.size = Vector2i(640, 360)
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		root.add_child(view)
		var board: Board = Board.new()
		board.grey = blind
		view.add_child(board)
		var count: int = 0
		for id: String in ["gravekeeper", "furnace_colossus"]:
			var column: int = 0
			var row: int = 0 if id == "gravekeeper" else 1
			for action: String in ["idle", "run"]:
				for entry: Dictionary in catalog.entries:
					if entry["category"] != "boss" or entry["id"] != id or entry["action"] != action:
						continue
					var resource: Dictionary = catalog.read_entry(entry)
					if not resource["error"].is_empty():
						push_error(resource["error"])
						quit(1)
						return
					for index: int in 2:
						var frame: Dictionary = resource["frames"][index]
						var sprite: Sprite2D = Sprite2D.new()
						sprite.texture = resource["texture"]
						sprite.region_enabled = true
						sprite.region_rect = frame["rect"]
						sprite.region_filter_clip_enabled = true
						sprite.centered = false
						var pivot: Vector2 = Vector2(85 + column * 150, 130 + row * 175)
						sprite.position = pivot - frame["pivot"]
						if blind:
							var shader: Shader = Shader.new()
							shader.code = "shader_type canvas_item; void fragment(){vec4 c=texture(TEXTURE,UV); float shadow=step(distance(c.rgb,vec3(11.,10.,18.)/255.),0.001); COLOR=vec4(0.,0.,0.,c.a*(1.-shadow));}"
							var material: ShaderMaterial = ShaderMaterial.new()
							material.shader = shader
							sprite.material = material
						board.add_child(sprite)
						count += 1
						answers[str(count)] = {"id": id, "action": action, "frame": index}
						board.captions.append({"at": pivot + Vector2(-30, 20), "text": "#%02d" % count if blind else "%s %d" % [action, index]})
						column += 1
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var filename: String = "silhouettes_1x.png" if blind else "poses_1x.png"
		if view.get_texture().get_image().save_png(out.path_join(filename)) != OK:
			push_error("RK075 preview save failed")
		if not blind:
			var large: SubViewport = SubViewport.new()
			large.size = Vector2i(1920, 1080)
			large.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(large)
			var screen: TextureRect = TextureRect.new()
			screen.texture = view.get_texture()
			screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			screen.size = Vector2(1920, 1080)
			large.add_child(screen)
			await process_frame
			await RenderingServer.frame_post_draw
			if large.get_texture().get_image().save_png(out.path_join("poses_3x.png")) != OK:
				push_error("RK075 large preview save failed")
			large.queue_free()
		view.queue_free()
		await process_frame
	var file: FileAccess = FileAccess.open(out.path_join("silhouette_answers.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(answers, "\t") + "\n")
	file.close()
	print("RK075_PREVIEW: passed")
	quit()
