class_name InputCollector
extends RefCounted

var _world_canvas: CanvasItem
var _fire_held: bool = false
var _fire_presses: int = 0
var _switch_steps: int = 0

## 配置世界坐标上下文；旧场景不配置时保留仅移动行为。
func configure(world_canvas: CanvasItem) -> void:
	_world_canvas = world_canvas
	reset()

## 未处理的按下缓存意图；全局转发allow_press=false只收松开，避免GUI松开粘滞。
func feed_event(event: InputEvent, allow_press: bool = true) -> void:
	if not is_instance_valid(_world_canvas):
		return
	if event.is_action_released(&"fire"):
		_fire_held = false
		return
	if not allow_press or (event is InputEventKey and event.echo):
		return
	if event.is_action_pressed(&"fire") and not _fire_held:
		_fire_held = true
		_fire_presses += 1
	if event.is_action_pressed(&"weapon_next"):
		_switch_steps += 1
	if event.is_action_pressed(&"weapon_previous"):
		_switch_steps -= 1

## 清掉待消费边沿及held；不轮询物理按键重建开火状态。
func reset() -> void:
	_fire_held = false
	_fire_presses = 0
	_switch_steps = 0

## 每逻辑步保留移动幅度和held；开火/切槽边沿仅消费一次。
func sample() -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.move_direction = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down", 0.2)
	if is_instance_valid(_world_canvas):
		frame.aim_world = _world_canvas.get_global_mouse_position()
		frame.aim_valid = frame.aim_world.is_finite()
		frame.fire_held = _fire_held
		frame.fire_presses = _fire_presses
		frame.switch_steps = _switch_steps
		_fire_presses = 0
		_switch_steps = 0
	return frame
