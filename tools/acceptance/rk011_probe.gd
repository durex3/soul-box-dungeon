extends SceneTree

const ARENA_SCENE: PackedScene = preload("res://view/battle/arena_view.tscn")

var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _require(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		print("RK011_FAIL " + message)


func _run() -> void:
	var arena: ArenaView = ARENA_SCENE.instantiate() as ArenaView
	_require(arena != null, "正式场景必须能实例化为 ArenaView")
	if arena == null:
		quit(1)
		return
	_require(arena.scale == Vector2.ONE, "场景不得缩放")
	_require(ArenaConfig.OUTER_SIZE == Vector2i(1280, 720), "外框尺寸错误")
	_require(ArenaConfig.TILE_PX == 16 and ArenaConfig.WALL_TILES == 2, "格与墙厚配置错误")
	_require(ArenaBounds.outer_rect() == Rect2(0, 0, 1280, 720), "外框错误")
	_require(ArenaBounds.play_rect() == Rect2(32, 32, 1216, 656), "活动区域错误")
	_require(ArenaView.GROUND_COLOR == Color("#1C1B26"), "地面色错误")
	_require(ArenaView.WALL_COLOR == Color("#2E2A3A"), "墙色错误")
	_require(ArenaView.GRID_COLOR.a == 0.25, "网格透明度错误")
	for radius: float in [8.0, 16.0]:
		var position: Vector2 = ArenaBounds.clamp_position(Vector2(-1000, 9000), radius)
		_require(position == Vector2(32 + radius, 688 - radius), "标记夹取范围错误")
		_require(ArenaBounds.contains_circle(position, radius), "标记约束失败")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		root.add_child(arena)
		await process_frame
	else:
		if args.size() != 2 or args[0] != "--export-image":
			arena.free()
			_require(false, "不支持的导出参数")
			_finish()
			return
		var viewport: SubViewport = SubViewport.new()
		viewport.size = ArenaConfig.OUTER_SIZE
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewport.add_child(arena)
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		_require(image.get_size() == ArenaConfig.OUTER_SIZE, "导出图尺寸错误")
		_require(image.save_png(args[1]) == OK, "PNG 保存失败")
		var samples: Dictionary = {
			"corner_tl": Vector2i(0, 0), "corner_tr": Vector2i(1279, 0),
			"corner_bl": Vector2i(0, 719), "corner_br": Vector2i(1279, 719),
			"top": Vector2i(640, 16), "bottom": Vector2i(640, 704),
			"left": Vector2i(16, 360), "right": Vector2i(1264, 360),
			"ground": Vector2i(33, 33), "grid_v": Vector2i(48, 49),
			"grid_h": Vector2i(49, 48), "grid_cross": Vector2i(48, 48),
		}
		print("RK011_IMAGE %s %dx%d" % [args[1], image.get_width(), image.get_height()])
		for name: String in samples:
			var point: Vector2i = samples[name]
			print("RK011_SAMPLE %s (%d,%d) #%s" % [name, point.x, point.y, image.get_pixelv(point).to_html(false)])
	_finish()


func _finish() -> void:
	print("RK011_PROBE: failed" if _failed else "RK011_PROBE: passed")
	quit(1 if _failed else 0)
