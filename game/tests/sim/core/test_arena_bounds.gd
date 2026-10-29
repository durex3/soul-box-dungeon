extends GdTest


## 外框、内框、中心及墙厚符合确认口径。
func test_rectangles() -> void:
	eq(ArenaBounds.outer_rect(), Rect2(0, 0, 1280, 720))
	eq(ArenaBounds.play_rect(), Rect2(32, 32, 1216, 656))
	eq(ArenaBounds.play_rect().end, Vector2(1248, 688))
	eq(ArenaBounds.play_rect().get_center(), Vector2(640, 360))
	eq(ArenaConfig.WALL_TILES * ArenaConfig.TILE_PX, 32)


## 三种半径分别越过四边四角，均落在独立参考端点。
func test_clamp_edges_and_corners() -> void:
	for radius: float in [0.0, 8.0, 16.0]:
		var low: Vector2 = Vector2(32 + radius, 32 + radius)
		var high: Vector2 = Vector2(1248 - radius, 688 - radius)
		eq(ArenaBounds.clamp_position(Vector2(640, 360), radius), Vector2(640, 360))
		var cases: Array[Array] = [
			[Vector2(-100, 360), Vector2(low.x, 360)],
			[Vector2(2000, 360), Vector2(high.x, 360)],
			[Vector2(640, -100), Vector2(640, low.y)],
			[Vector2(640, 2000), Vector2(640, high.y)],
			[Vector2(-100, -100), low], [Vector2(2000, 2000), high],
			[Vector2(-100, 2000), Vector2(low.x, high.y)],
			[Vector2(2000, -100), Vector2(high.x, low.y)],
			[Vector2(640, 360) + Vector2(100000, -100000), Vector2(high.x, low.y)],
		]
		for pair: Array in cases:
			var clamped: Vector2 = ArenaBounds.clamp_position(pair[0], radius)
			eq(clamped, pair[1])
			ok(ArenaBounds.contains_circle(clamped, radius))
	# 默认半径与显式零半径一致。
	eq(ArenaBounds.clamp_position(Vector2(-1, 999)), Vector2(32, 688))


## 四边四角相切合法，半径边缘越界 0.001 像素则非法。
func test_contains_entire_circle_inclusive() -> void:
	for radius: float in [0.0, 8.0, 16.0]:
		var low: Vector2 = Vector2(32 + radius, 32 + radius)
		var high: Vector2 = Vector2(1248 - radius, 688 - radius)
		for point: Vector2 in [low, high, Vector2(low.x, high.y), Vector2(high.x, low.y),
			Vector2(low.x, 360), Vector2(high.x, 360), Vector2(640, low.y), Vector2(640, high.y)]:
			ok(ArenaBounds.contains_circle(point, radius))
		for point: Vector2 in [Vector2(low.x - 0.001, 360), Vector2(high.x + 0.001, 360),
			Vector2(640, low.y - 0.001), Vector2(640, high.y + 0.001)]:
			ok(not ArenaBounds.contains_circle(point, radius))
			ok(ArenaBounds.contains_circle(ArenaBounds.clamp_position(point, radius), radius))
	ok(ArenaBounds.contains_circle(Vector2(1248, 688)))


## 玩家和敌人标记使用同一组固定输入和正式约束函数。
func test_player_and_enemy_markers() -> void:
	var moves: Array[Vector2] = [Vector2(3000, 0), Vector2(0, -3000), Vector2(-3000, 3000),
		Vector2(5000, -5000), Vector2(-7, 11), Vector2(123, 456)]
	for radius: float in [8.0, 16.0]:
		var position: Vector2 = Vector2(640, 360)
		for i: int in 10000:
			position = ArenaBounds.clamp_position(position + moves[i % moves.size()], radius)
			ok(ArenaBounds.contains_circle(position, radius), "radius %s step %s" % [radius, i])


## 最大合法半径贴合上下边，并且重复约束幂等。
func test_max_radius_and_idempotence() -> void:
	var radius: float = 328.0
	var center: Vector2 = Vector2(640, 360)
	ok(ArenaBounds.contains_circle(center, radius))
	eq(ArenaBounds.clamp_position(center, radius), center)
	eq(ArenaBounds.clamp_position(Vector2(-99999, -99999), radius), Vector2(360, 360))
	eq(ArenaBounds.clamp_position(Vector2(99999, 99999), radius), Vector2(920, 360))
	for r: float in [0.0, 8.0, 16.0, radius]:
		var once: Vector2 = ArenaBounds.clamp_position(Vector2(-500, 9000), r)
		for i: int in 10:
			eq(ArenaBounds.clamp_position(once, r), once)
			ok(ArenaBounds.contains_circle(once, r))


## 非整数合法半径的夹取和包含判定使用同一浮点边界。
func test_fractional_radius_consistency() -> void:
	for radius: float in [0.1, 1.0 / 3.0, 31.9, 327.9]:
		for point: Vector2 in [Vector2(-99999, -99999), Vector2(99999, 99999),
			Vector2(-99999, 99999), Vector2(99999, -99999)]:
			var clamped: Vector2 = ArenaBounds.clamp_position(point, radius)
			ok(ArenaBounds.contains_circle(clamped, radius), "radius %s at %s" % [radius, clamped])
			eq(ArenaBounds.clamp_position(clamped, radius), clamped)
