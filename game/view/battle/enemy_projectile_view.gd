class_name EnemyProjectileView
extends PooledView

var entity_id: int = -1
var diameter_px: int = 6
var world_position: Vector2 = Vector2.ZERO

func _init() -> void:
	_restore_style()

## 显示已借出的敌弹中心及含全部圈层的总直径；无模拟更新。
func present(id: int, at: Vector2, diameter: int) -> void:
	if not active:
		push_error("EnemyProjectileView.present: inactive")
		return
	if diameter < 6 or diameter > 32:
		push_error("EnemyProjectileView.present: invalid diameter")
		return
	entity_id = id
	world_position = at
	position = at.round()
	diameter_px = diameter
	_restore_style()
	queue_redraw()

func _on_pool_acquire() -> void:
	_reset()

func _on_pool_release() -> void:
	_reset()

func _reset() -> void:
	entity_id = -1
	diameter_px = 6
	world_position = Vector2.ZERO
	position = Vector2.ZERO
	_restore_style()
	queue_redraw()

func _restore_style() -> void:
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	self_modulate = Color.WHITE
	material = null
	z_as_relative = false
	z_index = BattleDrawOrder.ENEMY_PROJECTILES

func _draw() -> void:
	if not active:
		return
	var radius: float = diameter_px / 2.0
	var rings: int = 2 if diameter_px >= 10 else 1
	var origin: Vector2 = -Vector2(floorf(radius), floorf(radius))
	for y: int in diameter_px:
		for x: int in diameter_px:
			var offset: Vector2 = Vector2(x + 0.5, y + 0.5) - Vector2(radius, radius)
			var squared: float = offset.length_squared()
			if squared > radius * radius:
				continue
			var color: Color = Color("#FF2E97")
			if squared > (radius - rings) * (radius - rings):
				color = Color.WHITE
			if rings == 2 and squared > (radius - 1.0) * (radius - 1.0):
				color = Color("#2A0614")
			draw_rect(Rect2(origin + Vector2(x, y), Vector2.ONE), color)
