class_name FixedStepDriver
extends Node

var _clock: FixedStepClock = FixedStepClock.new()
var _step_callback: Callable = Callable()


func _ready() -> void:
	set_process(_step_callback.is_valid())


## 入树前绑定无参数的逻辑步回调，无效回调不启用处理。
func configure(step_callback: Callable) -> void:
	if is_inside_tree():
		push_error("FixedStepDriver.configure 必须在进入场景树前调用")
		return
	_step_callback = step_callback
	set_process(_step_callback.is_valid())


## 暂停或恢复固定步调度，不积累暂停时间。
func set_paused(value: bool) -> void:
	_clock.set_paused(value)


## 清空余数并恢复未暂停状态，保留已配置的回调。
func reset() -> void:
	_clock.reset()


func _process(delta: float) -> void:
	if not _step_callback.is_valid():
		set_process(false)
		return
	for i: int in _clock.advance(delta):
		_step_callback.call()
