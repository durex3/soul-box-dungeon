class_name ArenaBounds
extends RefCounted


## 返回包含围墙的竞技场外框。
static func outer_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(ArenaConfig.OUTER_SIZE))


## 从外框内缩围墙厚度，得到可活动区域。
static func play_rect() -> Rect2:
	return outer_rect().grow(-ArenaConfig.WALL_TILES * ArenaConfig.TILE_PX)


## 将圆心夹回合法范围，允许圆与内墙相切。
static func clamp_position(position: Vector2, radius: float = 0.0) -> Vector2:
	var rect: Rect2 = play_rect()
	var inset: Vector2 = Vector2(radius, radius)
	return position.clamp(rect.position + inset, rect.end - inset)


## 检查整个圆是否在内框内，显式包含右、下边界。
static func contains_circle(position: Vector2, radius: float = 0.0) -> bool:
	var rect: Rect2 = play_rect()
	# 与夹取使用完全相同的 Vector2 运算，避免非整数半径的舍入方向不同。
	var inset: Vector2 = Vector2(radius, radius)
	var low: Vector2 = rect.position + inset
	var high: Vector2 = rect.end - inset
	return (position.x >= low.x and position.y >= low.y
		and position.x <= high.x and position.y <= high.y)
