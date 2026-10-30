extends GdTest

func test_index_lifecycle() -> void:
	var grid: SpatialHash = SpatialHash.new()
	eq(grid.size(), 0)
	eq(grid.query_circle(Vector2.ZERO, 10), [])
	ok(not grid.has(0))
	ok(not grid.remove(-1))
	ok(grid.insert(0, Vector2.ZERO))
	ok(grid.insert(-9, Vector2.ZERO))
	ok(not grid.insert(0, Vector2(99, 99)))
	eq(grid.size(), 2)
	ok(grid.has(0))
	eq(grid.query_circle(Vector2.ZERO, 0), [-9, 0])
	eq(grid.query_circle(Vector2(99, 99), 0), [])
	ok(grid.remove(0))
	ok(not grid.remove(0))
	ok(not grid.has(0))
	ok(grid.remove(-9))
	eq(grid.size(), 0)
	# 空桶的内存清理约束无法仅从查询结果观察。
	eq((grid.get("_buckets") as Dictionary).size(), 0)
	grid.clear()
	grid.clear()
	ok(grid.insert(-1, Vector2(1, 2)))
	grid.clear()
	eq(grid.query_circle(Vector2(1, 2), 0), [])
	ok(grid.insert(0, Vector2.ZERO))

func test_grid_lines_and_negative_coordinates() -> void:
	var grid: SpatialHash = SpatialHash.new()
	var points: Dictionary = {}
	var values: Array[float] = [-64.001, -64, -0.001, 0, 63.999, 64]
	for x: float in values:
		for y: float in values:
			var id: int = points.size() - 18
			points[id] = Vector2(x, y)
			ok(grid.insert(id, points[id]))
	for point: Vector2 in points.values():
		eq(grid.query_circle(point, 0), _reference(points, point, 0))
		eq(grid.query_circle(point, 0.002), _reference(points, point, 0.002))
	# 直接核对负数向下取整，避免截断实现虽返回正确但落错桶。
	ok((grid.get("_buckets") as Dictionary).has(Vector2i(-2, -2)))

func test_circle_filter_and_boundaries() -> void:
	var points: Dictionary = {9: Vector2.ZERO, -3: Vector2(3, 4), 0: Vector2(-3, -4),
		2: Vector2(5.001, 0), 7: Vector2(4, 4), 11: Vector2(-4, 3),
		-11: Vector2(4, -3), 22: Vector2(130, 64), -22: Vector2(-130, -64)}
	var grid: SpatialHash = _build(points, points.keys())
	eq(grid.query_circle(Vector2.ZERO, 5), [-11, -3, 0, 9, 11])
	eq(grid.query_circle(Vector2.ZERO, 0), [9])
	eq(grid.query_circle(Vector2.ZERO, -1), [])
	eq(grid.query_circle(Vector2.ZERO, 2048), _reference(points, Vector2.ZERO, 2048))
	eq(grid.query_circle(Vector2(64, -64), 150), _reference(points, Vector2(64, -64), 150))

func test_move_and_bucket_cleanup() -> void:
	var grid: SpatialHash = SpatialHash.new()
	ok(not grid.move(42, Vector2.ZERO))
	ok(grid.insert(42, Vector2(10, 10)))
	var previous: Vector2 = Vector2(10, 10)
	for repeat: int in 5:
		for point: Vector2 in [Vector2(10, 10), Vector2(11, 12), Vector2(64, 64),
				Vector2(-0.001, -64.001), Vector2(-4096, 4096), Vector2(4096, -4096)]:
			ok(grid.move(42, point))
			eq(grid.query_circle(point, 0), [42])
			if point != previous:
				eq(grid.query_circle(previous, 0), [])
			eq(grid.size(), 1)
			eq((grid.get("_buckets") as Dictionary).size(), 1)
			previous = point
	ok(grid.remove(42))
	eq(grid.query_circle(previous, 0), [])
	ok(grid.insert(42, previous))
	eq(grid.query_circle(previous, 0), [42])

func test_order_independence_and_result_copy() -> void:
	var points: Dictionary = _fixture(100)
	# 特意让同桶顺序也不是升序，去掉sort时必定暴露错误。
	points[9] = Vector2.ZERO
	points[-3] = Vector2.ZERO
	points[0] = Vector2.ZERO
	points[2] = Vector2.ZERO
	var forward: Array = points.keys()
	var reverse: Array = forward.duplicate()
	reverse.reverse()
	var a: SpatialHash = _build(points, forward)
	var b: SpatialHash = _build(points, reverse)
	var c: SpatialHash = _build(points, reverse)
	for id: int in forward:
		ok(c.remove(id))
		ok(c.insert(id, points[id]))
	for center: Vector2 in [Vector2.ZERO, Vector2(-64, 64)]:
		for radius: float in [0.0, 256.0, 2048.0]:
			var expected: Array[int] = _reference(points, center, radius)
			eq(a.query_circle(center, radius), expected)
			eq(b.query_circle(center, radius), expected)
			eq(c.query_circle(center, radius), expected)
	var returned: Array[int] = a.query_circle(Vector2.ZERO, 2048)
	returned.clear()
	returned.append(999999)
	eq(a.query_circle(Vector2.ZERO, 2048), _reference(points, Vector2.ZERO, 2048))

func test_random_1000_points_100_queries() -> void:
	var points: Dictionary = _fixture(1000)
	var grid: SpatialHash = _build(points, points.keys())
	_compare_queries(grid, points)

func test_mutated_fixture_and_crowded_clear() -> void:
	var points: Dictionary = _fixture(1000)
	var grid: SpatialHash = _build(points, points.keys())
	var keys: Array = points.keys()
	for i: int in keys.size():
		var id: int = keys[i]
		if i % 5 == 0:
			ok(grid.remove(id))
			points.erase(id)
		elif i % 3 == 0:
			var point: Vector2 = -points[id] + Vector2(64, -64)
			ok(grid.move(id, point))
			points[id] = point
	_compare_queries(grid, points)
	grid.clear()
	var expected: Array[int] = []
	for id: int in range(-150, 150):
		ok(grid.insert(id, Vector2(640, 360)))
		expected.append(id)
	eq(grid.query_circle(Vector2(640, 360), 0), expected)
	eq(grid.query_circle(Vector2(640, 360), 112), expected)
	grid.clear()
	eq(grid.query_circle(Vector2(640, 360), 2048), [])
	eq(grid.size(), 0)

func _fixture(count: int) -> Dictionary:
	var rng: RandomNumberGenerator = RunRng.new(20261030).spawn
	var points: Dictionary = {}
	for i: int in count:
		points[1000 + i] = Vector2(rng.randf_range(-1024, 1024), rng.randf_range(-1024, 1024))
	return points

func _build(points: Dictionary, order: Array) -> SpatialHash:
	var grid: SpatialHash = SpatialHash.new()
	for id: int in order:
		ok(grid.insert(id, points[id]))
	return grid

func _reference(points: Dictionary, center: Vector2, radius: float) -> Array[int]:
	var result: Array[int] = []
	for id: int in points:
		var point: Vector2 = points[id]
		if radius >= 0 and point.distance_squared_to(center) <= radius * radius:
			result.append(id)
	result.sort()
	return result

func _compare_queries(grid: SpatialHash, points: Dictionary) -> void:
	var rng: RandomNumberGenerator = RunRng.new(20261030).spawn
	for i: int in 100:
		var center: Vector2 = Vector2(rng.randf_range(-1024, 1024), rng.randf_range(-1024, 1024))
		var radius: float = rng.randf_range(0, 256)
		eq(grid.query_circle(center, radius), _reference(points, center, radius), "query %d" % i)
