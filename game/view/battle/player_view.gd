class_name PlayerView
extends Node2D

var _sprite: Sprite2D = Sprite2D.new()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/greybox/rk073/chr_knight_idle.json"))
	var frame: Dictionary = meta["frames"][0]
	_sprite.texture = load("res://assets/sprites/greybox/rk073/chr_knight_idle.png")
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.region_filter_clip_enabled = true
	_sprite.region_rect = Rect2(frame["frame"]["x"], frame["frame"]["y"], frame["frame"]["w"], frame["frame"]["h"])
	_sprite.position = -Vector2(frame["pivot"]["x"], frame["pivot"]["y"])
	add_child(_sprite)

## 同步只读逻辑中心；不将画布尺寸用于模拟碰撞。
func sync(player: PlayerState) -> void:
	position = player.position
