extends SceneTree

func _initialize() -> void:
	var rng: RandomNumberGenerator = RunRng.new(20261030).spawn
	var uniform: Array[Vector2] = []
	var crowded: Array[Vector2] = []
	var centers: Array[Vector2] = []
	for i: int in 300:
		uniform.append(Vector2(rng.randf_range(32, 1248), rng.randf_range(32, 688)))
		crowded.append(Vector2(640, 360))
	for i: int in 100:
		centers.append(Vector2(rng.randf_range(32, 1248), rng.randf_range(32, 688)))
	print("RK007 environment: ", Engine.get_version_info()["string"], " debug=", OS.is_debug_build(), " headless; CPU=", OS.get_processor_name(), " system=", OS.get_name(), " ", OS.get_version())
	if not _measure("uniform", uniform, centers) or not _measure("crowded", crowded, centers):
		quit(1)
		return
	print("RK007_PROBE: passed")
	quit()

func _measure(label: String, points: Array[Vector2], centers: Array[Vector2]) -> bool:
	var grid: SpatialHash = SpatialHash.new()
	for id: int in points.size():
		if not grid.insert(id, points[id]):
			push_error("RK007 insert failed")
			return false
	for center: Vector2 in centers:
		var expected: Array[int] = []
		for id: int in points.size():
			if points[id].distance_squared_to(center) <= 112.0 * 112.0:
				expected.append(id)
		if grid.query_circle(center, 112.0) != expected:
			push_error("RK007 reference mismatch: " + label)
			return false
	var checksum: int = 0
	for i: int in 1000:
		checksum += grid.query_circle(centers[i % 100], 112.0).size()
	var means: Array[float] = []
	for batch: int in 5:
		var start: int = Time.get_ticks_usec()
		for i: int in 10000:
			checksum += grid.query_circle(centers[i % 100], 112.0).size()
		var elapsed: int = Time.get_ticks_usec() - start
		var average: float = float(elapsed) / 10000.0
		means.append(average)
		print("RK007 ", label, " batch=", batch + 1, " total_us=", elapsed, " mean_us=", average)
	var total: float = 0.0
	for value: float in means:
		total += value
	print("RK007 ", label, " mean_us=", total / 5.0, " min_us=", means.min(), " max_us=", means.max(), " accumulated_results=", checksum, " (includes warmup)")
	return true
