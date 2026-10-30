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
	var bosses: Dictionary = {}
	for entry: Dictionary in lab.catalog.entries:
		var result: Dictionary = lab.catalog.read_entry(entry)
		if not result["error"].is_empty():
			push_error(result["error"])
			quit(1)
			return
		if entry["category"] == "boss":
			var key: String = entry["id"] + "/" + entry["action"]
			var n: int = 64 if entry["id"] == "gravekeeper" else 96
			if bosses.has(key) or result["frames"].size() != 2:
				push_error("RK119 duplicate Boss or wrong frame count")
				quit(1)
				return
			bosses[key] = true
			for frame: Dictionary in result["frames"]:
				if frame["rect"].size != Vector2(n, n) or frame["pivot"] != Vector2(n / 2, n - 3) or frame["duration"] != (167 if entry["action"] == "idle" else 83):
					push_error("RK119 Boss canvas/pivot/duration mismatch")
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
	if bosses.size() != 4 or not ["gravekeeper/idle", "gravekeeper/run", "furnace_colossus/idle", "furnace_colossus/run"].all(func(key: String) -> bool: return bosses.has(key)):
		push_error("RK119 exact four Boss identities missing")
		quit(1)
		return
	if count != 100 or animations != 40 or statics != 60 or lab.preview == null or lab.resource.get("frames", []).is_empty():
		push_error("RK119 catalog mismatch: %d/%d/%d" % [count, animations, statics])
		quit(1)
		return
	print("RK119 catalog: %d resources, %d animated, %d static" % [count, animations, statics])
	print("RK119_SMOKE: passed")
	lab.queue_free()
	await process_frame
	quit()
