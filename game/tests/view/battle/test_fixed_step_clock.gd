extends GdTest

const SPEED: float = 64.0


## 零时间不推进，半帧合并且跨调用保留余数。
func test_zero_and_fractional_steps() -> void:
	var clock: FixedStepClock = FixedStepClock.new()
	eq(clock.advance(0.0), 0)
	eq(clock.advance(Sim.DT / 2.0), 0)
	eq(clock.advance(Sim.DT / 2.0), 1)
	eq(clock.advance(Sim.DT * 1.5), 1)
	eq(clock.advance(0.0), 0)
	eq(clock.advance(Sim.DT * 0.5), 1)


## 30 fps 合成十秒得到 600 步、640 像素。
func test_synthetic_30_fps() -> void:
	var steps: int = _advance_frames(300, 1.0 / 30.0)
	eq(steps, 600)
	near(steps * SPEED * Sim.DT, 640.0, 0.000001)


## 60 fps 合成十秒得到 600 步、640 像素。
func test_synthetic_60_fps() -> void:
	var steps: int = _advance_frames(600, 1.0 / 60.0)
	eq(steps, 600)
	near(steps * SPEED * Sim.DT, 640.0, 0.000001)


## 高频渲染不强制每次推进，允许一逻辑步以内的浮点边界差。
func test_synthetic_144_fps() -> void:
	var steps: int = _advance_frames(1440, 1.0 / 144.0)
	ok(steps == 599 or steps == 600)
	var reference: float = _advance_frames(300, 1.0 / 30.0) * SPEED * Sim.DT
	ok(absf(reference - steps * SPEED * Sim.DT) <= SPEED * Sim.DT + 0.000001)


## 长帧只纳入四分之一秒，多余时间不在后续调用追赶。
func test_long_frame_clamp() -> void:
	for delta: float in [0.25, 1.0]:
		var clock: FixedStepClock = FixedStepClock.new()
		eq(clock.advance(delta), 15)
		eq(clock.advance(0.0), 0)


## 负时间不扣除已有余数。
func test_negative_delta_preserves_remainder() -> void:
	var clock: FixedStepClock = FixedStepClock.new()
	eq(clock.advance(Sim.DT / 2.0), 0)
	eq(clock.advance(-1.0), 0)
	eq(clock.advance(Sim.DT / 2.0), 1)


## 暂停保留半帧，丢弃暂停期间的时间。
func test_pause_preserves_remainder() -> void:
	var clock: FixedStepClock = FixedStepClock.new()
	eq(clock.advance(Sim.DT / 2.0), 0)
	clock.set_paused(true)
	eq(clock.advance(10.0), 0)
	clock.set_paused(false)
	eq(clock.advance(Sim.DT / 2.0), 1)
	eq(clock.advance(0.0), 0)


## 新时钟暂停后任何调用都不产生步数。
func test_paused_clock_drops_time() -> void:
	var clock: FixedStepClock = FixedStepClock.new()
	clock.set_paused(true)
	for delta: float in [0.0, 10.0, 0.25, Sim.DT, -1.0]:
		eq(clock.advance(delta), 0)
	clock.set_paused(false)
	eq(clock.advance(Sim.DT), 1)


## 重置同时清理余数和暂停状态。
func test_reset_clears_remainder_and_pause() -> void:
	var clock: FixedStepClock = FixedStepClock.new()
	clock.advance(Sim.DT / 2.0)
	clock.set_paused(true)
	clock.reset()
	eq(clock.advance(Sim.DT / 2.0), 0)
	eq(clock.advance(Sim.DT / 2.0), 1)


func _advance_frames(count: int, delta: float) -> int:
	var clock: FixedStepClock = FixedStepClock.new()
	var steps: int = 0
	for i: int in count:
		steps += clock.advance(delta)
	return steps
