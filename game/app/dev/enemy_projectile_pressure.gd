class_name EnemyProjectilePressure
extends Node2D

var full_cover: bool = true

func _init() -> void:
	z_as_relative = false
	z_index = BattleDrawOrder.ALLY_FX

func _draw() -> void:
	if full_cover:
		draw_rect(Rect2(0, 0, 160, 80), Color("#4F7BFF"))
		for i: int in 20:
			draw_rect(Rect2(i * 8, 0, 5, 80), Color("#F0F0F0"))
		for i: int in 16:
			draw_rect(Rect2(0, i * 5, 160, 3), Color("#3DF2C5"))
	else:
		draw_rect(Rect2(0, 0, 50, 20), Color("#FF8A1F"))
