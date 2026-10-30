extends SceneTree
## 仅实例化并截图其他调试场景，不修改其字体或生产文件。

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(640, 360)
	root.content_scale_size = Vector2i(640, 360)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var path: String = "res://app/dev/asset_review_lab.tscn" if args[0] == "rk119" else "res://app/dev/player_movement_lab.tscn"
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	if scene is PlayerMovementLab:
		scene.driver.set_paused(true)
	await process_frame
	await process_frame
	var findings: Array[Dictionary] = []
	for control: Control in scene.find_children("*", "Control", true, false):
		if not control is Button and not control is Label:
			continue
		var text: String = control.text
		var font: Font = control.get_theme_font("font")
		var missing: String = ""
		for character: String in text:
			if character.unicode_at(0) >= 32 and not font.has_char(character.unicode_at(0)) and not missing.contains(character):
				missing += character
		if not missing.is_empty():
			findings.append({"text": text, "font": font.get_font_name(), "missing_from_primary": missing})
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(args[1].path_join("font_audit_" + args[0] + ".png")) != OK:
		push_error("RK045 audit capture failed")
	print("RK045 font read-only audit " + args[0] + " " + JSON.stringify(findings))
	var file: FileAccess = FileAccess.open(args[1].path_join("font_audit_" + args[0] + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(findings, "\t") + "\n")
	file.close()
	scene.queue_free()
	await process_frame
	print("RK045_FONT_AUDIT: passed")
	quit()
