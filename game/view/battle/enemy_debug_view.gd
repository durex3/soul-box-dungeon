class_name EnemyDebugView
extends Node2D
## RK041 的只读圆形观察标记，不代表正式敌种外观或动画。

var _radius: float = EnemyConfig.DEFAULT_RADIUS
var _direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	z_index = BattleDrawOrder.ENTITIES
	z_as_relative = false

## 保留逻辑小数位置，仅绘图使用当前圆半径与面向玩家的方向。
func sync(enemy: EnemyState, target: Vector2) -> void:
	position = enemy.position
	_radius = enemy.radius
	_direction = (target - position).normalized()
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, Color("#0B0A12"))
	draw_circle(Vector2.ZERO, _radius - 1.0, Color("#70657C"))
	draw_line(Vector2.ZERO, (_direction * (_radius - 2.0)).round(), Color("#B4ADBF"), 1.0)
