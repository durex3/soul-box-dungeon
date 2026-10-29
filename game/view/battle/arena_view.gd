class_name ArenaView
extends Node2D

# style-bible 11、15 节：区域 1 灰盒地面与石头暗色围墙。
const GROUND_COLOR: Color = Color("#1C1B26")
const WALL_COLOR: Color = Color("#2E2A3A")
const GRID_COLOR: Color = Color(WALL_COLOR.r, WALL_COLOR.g, WALL_COLOR.b, 0.25)


func _draw() -> void:
	var outer: Rect2 = ArenaBounds.outer_rect()
	var play: Rect2 = ArenaBounds.play_rect()
	draw_rect(outer, GROUND_COLOR)
	for x: int in range(int(play.position.x), int(play.end.x), ArenaConfig.TILE_PX):
		draw_rect(Rect2(x, play.position.y, 1, play.size.y), GRID_COLOR)
	for y: int in range(int(play.position.y), int(play.end.y), ArenaConfig.TILE_PX):
		draw_rect(Rect2(play.position.x, y, play.size.x, 1), GRID_COLOR)
	# 顶底覆盖四角；左右只填中间，墙体绘制在网格之后。
	draw_rect(Rect2(outer.position, Vector2(outer.size.x, play.position.y)), WALL_COLOR)
	draw_rect(Rect2(0, play.end.y, outer.size.x, outer.end.y - play.end.y), WALL_COLOR)
	draw_rect(Rect2(0, play.position.y, play.position.x, play.size.y), WALL_COLOR)
	draw_rect(Rect2(play.end.x, play.position.y, outer.end.x - play.end.x, play.size.y), WALL_COLOR)
