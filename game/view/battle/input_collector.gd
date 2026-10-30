class_name InputCollector
extends RefCounted

## 每逻辑步读取共享动作，保留径向死区重映射后的模拟幅度。
func sample() -> InputFrame:
	var frame: InputFrame = InputFrame.new()
	frame.move_direction = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down", 0.2)
	return frame
