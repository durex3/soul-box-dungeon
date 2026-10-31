class_name WeaponDebugView
extends Node2D
## 只显示瞄准及开火事件方向，不代表实际弹道/近战判定。

var _origin: Vector2 = Vector2.ZERO
var _target: Vector2 = Vector2.ZERO
var _direction: Vector2 = Vector2.RIGHT
var _markers: Array[Dictionary] = []

func _ready() -> void:
	z_index = BattleDrawOrder.ALLY_FX
	z_as_relative = false

## 复制只读事件值与世界坐标，绝不写模拟状态。
func sync(player: PlayerState, input: InputFrame, events: Array[SimEvent]) -> void:
	_origin = player.position
	_direction = player.weapon.aim_direction
	_target = input.aim_world if input.aim_valid else _origin + _direction * 80.0
	for event: SimEvent in events:
		if event.kind == SimEvent.Kind.WEAPON_FIRED:
			_markers.append({"origin": event.origin, "direction": event.direction, "remaining": 0.16})
	queue_redraw()

## 重建观察场景时清掉旧事件的短暂显示。
func reset() -> void:
	_markers.clear()
	queue_redraw()

func _process(delta: float) -> void:
	for i: int in range(_markers.size()-1,-1,-1):
		_markers[i].remaining -= delta
		if _markers[i].remaining <= 0.0:
			_markers.remove_at(i)
	queue_redraw()

func _draw() -> void:
	draw_line(_origin.round(), _target.round(), Color("#769EB5"),2.0)
	draw_line((_target-Vector2(4,0)).round(), (_target+Vector2(4,0)).round(),Color("#8FBDD3"),1.0)
	draw_line((_target-Vector2(0,4)).round(), (_target+Vector2(0,4)).round(),Color("#8FBDD3"),1.0)
	for marker: Dictionary in _markers:
		var start: Vector2 = marker.origin + marker.direction * 22.0
		var end: Vector2 = marker.origin + marker.direction * 44.0
		draw_line(start.round(), end.round(), Color("#CEE5EC"),2.0)
