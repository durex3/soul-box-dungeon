extends Node2D

const VIEWPORT_SIZE: Vector2i = Vector2i(640, 360)
const GRID_PX: int = 16
const CHECKER_PX: int = 4
const GROUND_COLOR: Color = Color("#1C1B26")
const GRID_COLOR: Color = Color("#3D3850")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE)), GROUND_COLOR)
	# 用整数坐标的实心矩形保证网格恰好占一列或一行像素。
	for x: int in range(0, VIEWPORT_SIZE.x, GRID_PX):
		draw_rect(Rect2(x, 0, 1, VIEWPORT_SIZE.y), GRID_COLOR)
	for y: int in range(0, VIEWPORT_SIZE.y, GRID_PX):
		draw_rect(Rect2(0, y, VIEWPORT_SIZE.x, 1), GRID_COLOR)
	for y: int in range(CHECKER_PX):
		for x: int in range(CHECKER_PX):
			var color: Color = Color.WHITE if (x + y) % 2 == 0 else Color.BLACK
			draw_rect(Rect2(x, y, 1, 1), color)
