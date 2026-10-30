extends SceneTree
## 仅验证场景、生产目录和帧元数据；交互与视觉另做实际检查。

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://app/dev/asset_review_lab.tscn")
	var lab: AssetReviewLab = scene.instantiate() as AssetReviewLab
	root.add_child(lab)
	await process_frame
	var count: int = 0
	var animations: int = 0
	var statics: int = 0
	for entry: Dictionary in lab.catalog.entries:
		var result: Dictionary = lab.catalog.read_entry(entry)
		if not result["error"].is_empty():
			push_error(result["error"])
			quit(1)
			return
		for frame: Dictionary in result["frames"]:
			if frame["rect"].size.x <= 0 or frame["duration"] <= 0 or not frame["pivot"] is Vector2:
				push_error("RK119 invalid decoded frame: " + entry["path"])
				quit(1)
				return
		count += 1
		if result["frames"].size() > 1:
			animations += 1
		else:
			statics += 1
	if count != 96 or animations != 36 or statics != 60 or lab.preview == null or lab.resource.get("frames", []).is_empty():
		push_error("RK119 catalog mismatch: %d/%d/%d" % [count, animations, statics])
		quit(1)
		return
	print("RK119 catalog: %d resources, %d animated, %d static" % [count, animations, statics])
	print("RK119_SMOKE: passed")
	lab.queue_free()
	await process_frame
	quit()
