class_name FixedStepClock
extends RefCounted

const MAX_FRAME_TIME: float = 0.25

var _accum: float = 0.0
var _paused: bool = false


## 将渲染时间折算为固定步数，暂停期间的时间直接丢弃。
func advance(delta: float) -> int:
	if _paused:
		return 0
	_accum += clampf(delta, 0.0, MAX_FRAME_TIME)
	var steps: int = 0
	while _accum >= Sim.DT:
		_accum -= Sim.DT
		steps += 1
	return steps


## 切换暂停状态，保留暂停前不足一步的余数。
func set_paused(value: bool) -> void:
	_paused = value


## 恢复未暂停、无余数的初始状态。
func reset() -> void:
	_accum = 0.0
	_paused = false
