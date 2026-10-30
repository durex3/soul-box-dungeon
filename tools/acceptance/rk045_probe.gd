extends SceneTree

var _lab: EnemyProjectileLab
var _failed: bool = false
var _out: String
var _texts: Dictionary = {}
const TEXT_CHECK: Script = preload("rk045_text_check.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_out = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(640, 360)
	root.content_scale_size = Vector2i(640, 360)
	_lab = (load("res://app/dev/enemy_projectile_lab.tscn") as PackedScene).instantiate() as EnemyProjectileLab
	root.add_child(_lab)
	await process_frame
	await process_frame
	_check_text()
	await RenderingServer.frame_post_draw
	_save(root.get_texture().get_image(), "font_cold.png")
	if "--negative-font" in OS.get_cmdline_user_args():
		_lab.theme = null
		var missing: bool = false
		for error: String in TEXT_CHECK.errors(_lab):
			if error.begins_with("missing glyph U+654C") and error.contains("添加序 敌弹先"):
				missing = true
				print("RK045 old font detected: " + error)
				break
		_check(missing, "unbound font must fail actual glyph coverage")
		print("RK045_FONT_NEGATIVE: " + ("failed" if _failed else "passed"))
		_lab.queue_free()
		await process_frame
		quit(1 if _failed else 0)
		return
	var identity: int = _lab.bullet.get_instance_id()
	_check(_lab.pool.acquire() == null, "full pool returns null")
	for i: int in 1000:
		var item: EnemyProjectileView = _lab.bullet
		item.present(i, Vector2(10.3, 20.4), 6 + i % 27)
		item.rotation = 0.4
		item.scale = Vector2(2, 2)
		item.modulate = Color(0.5, 0.2, 0.1, 0.3)
		item.self_modulate = Color(0.1, 0.2, 0.3, 0.4)
		item.material = CanvasItemMaterial.new()
		_check(_lab.pool.release(item), "release")
		_check(not item.visible and not item.active and not item.can_process(), "returned hidden/stopped")
		var again: EnemyProjectileView = _lab.pool.acquire() as EnemyProjectileView
		_check(again.get_instance_id() == identity and again.diameter_px == 6 and again.entity_id == -1 and again.position == Vector2.ZERO, "reset payload")
		_check(again.rotation == 0 and again.scale == Vector2.ONE and again.modulate == Color.WHITE and again.self_modulate == Color.WHITE and again.material == null, "reset style")
	_check(_lab.pool.get_total_count() == 1 and _lab.pool.get_capacity() == 1, "fixed capacity after 1000 cycles")
	_lab.bullet.present(45, Vector2(80.3, 40.4), 6)
	for diameter: int in EnemyProjectileLab.SIZES:
		_check(_lab.bullet.diameter_px == diameter, "size UI updated payload")
		for order: int in 2:
			for alpha: int in 4:
				var name: String = "d%d_o%d_a%d" % [diameter, order, alpha]
				await process_frame
				await RenderingServer.frame_post_draw
				_save(_lab.viewport.get_texture().get_image(), name + "_world.png")
				_save(root.get_texture().get_image(), name + "_screen.png")
				await _click("Alpha")
			await _click("Order")
		await _click("Size")
	await _click("Return")
	_check(not _lab.bullet.visible and _lab.pool.get_active_count() == 0, "UI return")
	await RenderingServer.frame_post_draw
	_save(_lab.viewport.get_texture().get_image(), "returned_world.png")
	_save(root.get_texture().get_image(), "font_returned.png")
	await _click("Borrow")
	_check(_lab.bullet.get_instance_id() == identity and _lab.bullet.active, "UI reborrow same instance")
	await RenderingServer.frame_post_draw
	_save(_lab.viewport.get_texture().get_image(), "reborrow_world.png")
	await _click("Borrow")
	await RenderingServer.frame_post_draw
	_save(root.get_texture().get_image(), "font_full_pool.png")
	await _click("Cover")
	_check(not _lab.ally_fx.full_cover, "UI coverage toggle")
	await _click("Cover")
	await _click("Pause")
	_check(_lab.paused, "pause continuous rendering")
	await RenderingServer.frame_post_draw
	_save(root.get_texture().get_image(), "font_paused.png")
	await _click("Pause")
	print("RK045 synthetic mouse button/motion events; not physical mouse automation")
	print("RK045 pool: 1000 cycles, fixed capacity=1, same instance; capture pairs=56")
	var text_log: FileAccess = FileAccess.open(_out.path_join("font_texts.json"), FileAccess.WRITE)
	text_log.store_string(JSON.stringify(_texts.keys(), "\t") + "\n")
	text_log.close()
	print("RK045 text: cold start + every UI action, %d distinct labels checked" % _texts.size())
	print("RK045_GRAPHICS: " + ("failed" if _failed else "passed"))
	_lab.queue_free()
	await process_frame
	quit(1 if _failed else 0)

func _check_text() -> void:
	for control: Control in _lab.find_children("*", "Control", true, false):
		if control is Button or control is Label:
			_texts[control.text] = true
	for error: String in TEXT_CHECK.errors(_lab):
		_check(false, "TEXT " + error)

func _click(key: String) -> void:
	await process_frame
	var control: Control = _lab.controls[key]
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = motion.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame
	await process_frame
	_check_text()

func _save(image: Image, name: String) -> void:
	_check(image.save_png(_out.path_join(name)) == OK, "save " + name)

func _check(value: bool, label: String) -> void:
	if not value:
		_failed = true
		print("RK045 FAIL " + label)
